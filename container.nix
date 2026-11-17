# container.nix — OCI image assembly for the go-standard `container` option
#
# Backend: nix2container (github:nlewo/nix2container). Why not dockerTools:
#   - true OCI image-spec output (image.json + skopeo `nix:` transport)
#   - one layer per store-path group, so glibc/Go-runtime layers are SHARED
#     across every fleet image pushed to the same registry
#   - no tarball in the Nix store, no docker daemon at any point —
#     `copyToDockerDaemon`/`copyToRegistry` assemble at copy time via skopeo
#   - reproducible: fixed creation epoch + content-hash tag by default
#
# All option defaults are resolved by the caller (modules/go-standard.nix);
# this file only assembles: deterministic Env/Labels ordering, binary-closure
# relocation via buildEnv, volume provisioning with non-root ownership, and a
# jq-based structure gate over the produced image.json.
#
# OCI image-config keys are CAPITALIZED (User, Entrypoint, Env, ExposedPorts,
# Volumes, Labels): the nix2container Go binary unmarshals them into
# containers/image v1.ImageConfig, the image-spec config schema.
{
  pkgs,
  lib,
}:

let
  # "65532:65532" | "65532" | "nonroot" -> { uid, gid } | null
  # Volume ownership perms need NUMERIC ids; named users (distroless
  # "nonroot") cannot be auto-provisioned and get no perms entry.
  numericOwner =
    user:
    let
      parts = lib.splitString ":" user;
      first = builtins.head parts;
      lastPart = if builtins.length parts > 1 then lib.last parts else first;
      digits = s: builtins.match "[0-9]+" s != null;
    in
    if digits first && digits lastPart then
      {
        uid = lib.toInt first;
        gid = lib.toInt lastPart;
      }
    else
      null;
in
rec {
  # Deterministic Env list from an attrset. Attrset iteration order is
  # undefined in Nix; sorting by key keeps image hashes stable and diffs
  # reviewable. Consumer values override defaults BEFORE this call.
  envList = env: map (k: "${k}=${env.${k}}") (lib.naturalSort (lib.attrNames env));

  # OCI image-spec config (see capitalization note in the file header).
  mkImageConfig =
    {
      entrypoint,
      cmd ? [ ],
      env ? [ ],
      user,
      exposedPorts ? [ ],
      volumes ? [ ],
      labels ? { },
    }:
    {
      Entrypoint = entrypoint;
      Cmd = cmd;
      Env = env;
      User = user;
      ExposedPorts = lib.listToAttrs (map (p: lib.nameValuePair p { }) exposedPorts);
      Volumes = lib.listToAttrs (map (v: lib.nameValuePair v { }) volumes);
      Labels = labels;
    };

  # Provision declared volume directories with non-root ownership. A runtime
  # only creates anonymous volumes as root; without pre-provisioned dirs the
  # configured User cannot write them (bank-sync shipped this by hand).
  # Returns { dirs, perms } — dirs joins copyToRoot (store-prefix stripped,
  # landing at /<volume>), perms rides nix2container's tar-time chmod (uid/gid
  # applied without polluting the Nix store).
  mkVolumeDirs =
    {
      name,
      volumes,
      user,
    }:
    let
      owner = numericOwner user;
      dirs = pkgs.runCommand "${name}-volume-dirs" { } ''
        mkdir -p ${lib.concatMapStringsSep " " (v: "$out${v}") volumes}
      '';
    in
    {
      inherit dirs;
      perms =
        if owner == null then
          [ ]
        else
          map (v: {
            path = dirs;
            regex = "${v}.*";
            mode = "0755";
            inherit (owner) uid gid;
          }) volumes;
    };

  # Assemble the full image. `config` comes from mkImageConfig; `mainPackage`
  # lands at /bin/<name> via a buildEnv (symlink into /nix/store so libraries
  # are never duplicated between / and /nix/store — the nix2container idiom).
  # cacert rides along by default so TLS works everywhere (SSL_CERT_FILE is
  # set by the module's default env).
  mkContainerImage =
    {
      n2c,
      imageName,
      config,
      mainPackage,
      tag ? null,
      extraPackages ? [ ],
      pathsToLink ? [
        "/bin"
        "/etc"
      ],
      volumeDirs ? null,
      volumePerms ? [ ],
      maxLayers ? 20,
      created ? "0001-01-01T00:00:00Z",
      initializeNixDatabase ? false,
      meta ? { },
    }:
    let
      baseName = lib.last (lib.splitString "/" imageName);
    in
    n2c.buildImage {
      name = lib.toLower imageName;
      inherit
        tag
        maxLayers
        created
        initializeNixDatabase
        meta
        ;
      copyToRoot = [
        (pkgs.buildEnv {
          name = "${baseName}-image-root";
          paths = [
            mainPackage
            pkgs.cacert
          ]
          ++ extraPackages;
          inherit pathsToLink;
        })
      ]
      ++ lib.optional (volumeDirs != null) volumeDirs;
      perms = volumePerms;
      inherit config;
    };

  # Structure gate: build the image (forcing the nix2container Go binary,
  # which validates layers/perms) and assert the contract the module
  # promised. image.json embeds the full OCI image-config, so jq is the
  # whole oracle — expected values come from the SAME attrset the module
  # passed to buildImage (eval-known; no reading derivation outputs).
  mkContainerStructureCheck =
    {
      name,
      image,
      config,
      arch,
      created ? "0001-01-01T00:00:00Z",
    }:
    let
      expectedConfig = pkgs.writeText "${name}-expected-image-config.json" (builtins.toJSON config);
      configMatch = ''
        (
          (."image-config".User // "") == ($want[0].User // "")
          and (."image-config".Entrypoint // []) == ($want[0].Entrypoint // [])
          and (."image-config".Cmd // []) == ($want[0].Cmd // [])
          and (."image-config".Env // []) == ($want[0].Env // [])
          and (((."image-config".Labels // {}) * ($want[0].Labels // {})) == (."image-config".Labels // {}))
          and ([(."image-config".ExposedPorts // {}) | keys[]] | sort) == ([($want[0].ExposedPorts // {}) | keys[]] | sort)
          and ([(."image-config".Volumes // {}) | keys[]] | sort) == ([($want[0].Volumes // {}) | keys[]] | sort)
        )
      '';
      # Localized mismatch lines (empty output = match): names the exact
      # field(s) that drifted, with got/want values, instead of forcing a
      # by-eye diff of two full config dumps.
      configDiff = ''
        ."image-config" as $g | $want[0] as $w |
        (
          (if ($g.User // "") != ($w.User // "")
           then "  User: got \($g.User // "<unset>") want \($w.User // "<unset>")" else empty end),
          (if ($g.Entrypoint // []) != ($w.Entrypoint // [])
           then "  Entrypoint: got \($g.Entrypoint | tostring) want \($w.Entrypoint | tostring)" else empty end),
          (if ($g.Cmd // []) != ($w.Cmd // [])
           then "  Cmd: got \($g.Cmd | tostring) want \($w.Cmd | tostring)" else empty end),
          (if ($g.Env // []) != ($w.Env // [])
           then "  Env: got \($g.Env | tostring) want \($w.Env | tostring)" else empty end),
          (if (($g.Labels // {}) * ($w.Labels // {})) != ($g.Labels // {})
           then "  Labels: expected keys missing or changed: got \($g.Labels | tostring) want \($w.Labels | tostring)" else empty end),
          (if (([($g.ExposedPorts // {}) | keys[]] | sort) != ([($w.ExposedPorts // {}) | keys[]] | sort))
           then "  ExposedPorts: got \($g.ExposedPorts | keys | sort | tostring) want \($w.ExposedPorts | keys | sort | tostring)" else empty end),
          (if (([($g.Volumes // {}) | keys[]] | sort) != ([($w.Volumes // {}) | keys[]] | sort))
           then "  Volumes: got \($g.Volumes | keys | sort | tostring) want \($w.Volumes | keys | sort | tostring)" else empty end)
        )
      '';
    in
    pkgs.runCommand "${name}-container-structure"
      {
        nativeBuildInputs = [ pkgs.jq ];
      }
      ''
        imageJson="${image}"

        fail() {
          echo "FAIL: $1" >&2
          echo "--- image.json summary:" >&2
          jq '{arch, created, "image-config": .["image-config"], layers: (.layers | length)}' "$imageJson" >&2
          exit 1
        }

        jq -e '.layers | length >= 1' "$imageJson" >/dev/null \
          || fail "image has no layers"
        jq -e --arg arch "${arch}" '.arch == $arch' "$imageJson" >/dev/null \
          || fail "image arch is not ${arch}"
        jq -e --arg created "${created}" '.created == $created' "$imageJson" >/dev/null \
          || fail "image creation time is not the deterministic epoch"
        jq -e \
          '."image-config".User != "" and ."image-config".User != "root" and ."image-config".User != "0:0"' \
          "$imageJson" >/dev/null \
          || fail "image runs as root — container.user default was overridden with a root user"
        jq -e --slurpfile want "${expectedConfig}" '${configMatch}' "$imageJson" >/dev/null \
          || fail "image config does not match the module contract:$(printf '\n%s' "$(jq -r --slurpfile want "${expectedConfig}" '${configDiff}' "$imageJson")")"

        echo "PASS: ${name} container image structure"
        touch $out
      '';
}
