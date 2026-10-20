{ config, ... }:

# Recyclarr syncs TRaSH Guides' quality profiles, custom formats, file-size
# limits and naming into Radarr and Sonarr, daily. Everything it manages is
# overwritten on each run, so change those settings here rather than in the UIs.
#
# Two profiles each, chosen per movie/show (one copy each, no 4K instances):
#   Radarr  HD Bluray + WEB    1080p encodes; 720p disabled, never anything lower
#           Remux + WEB 2160p  4K remuxes, with audio formats for HD passthrough
#   Sonarr  WEB-1080p          1080p WEB-DLs, what nearly all good TV releases are
#           WEB-2160p          4K WEB-DLs, for HDR
#
# trash_ids come from the TRaSH-Guides repo (docs/json/{radarr,sonarr}/), and
# the group/select layout mirrors recyclarr's config-templates for these profiles.

let
  hdBlurayWeb   = "d1d67249d3890e49bc12e275d989a7e9";  # HD Bluray + WEB
  remuxWeb2160p = "fd161a61e3ab826d3a22d53f935696dd";  # Remux + WEB 2160p
  web1080p      = "72dae194fc92bf828f32cde7744e51a1";  # WEB-1080p
  web2160p      = "d1498e7d189fbe6c7110ceaabb7473e6";  # WEB-2160p

  uhdOnly       = [ { trash_id = remuxWeb2160p; } ];
  uhdOnlySonarr = [ { trash_id = web2160p; } ];
in
{
  # Each api_key reads the same secret its *arr's APIKEY is templated from
  # (radarr.nix, sonarr.nix), so the two can never disagree.
  services.recyclarr = {
    enable = true;
    configuration.radarr.calliope = {
      base_url = "http://127.0.0.1:7878";
      api_key._secret = config.sops.secrets."radarr-api-key".path;

      delete_old_custom_formats = true;

      quality_definition.type = "movie";

      # Required by TRaSH: the Repack/Proper custom formats handle these instead.
      media_management.propers_and_repacks = "do_not_prefer";

      # TMDb rather than IMDb ids: TRaSH notes TMDb always matches in Plex.
      media_naming = {
        folder = "plex-tmdb";
        movie = {
          rename   = true;
          standard = "plex-tmdb";
        };
      };

      quality_profiles = [
        {
          trash_id = hdBlurayWeb;
          reset_unmatched_scores.enabled = true;
          # The guide allows Bluray-720p as a fallback; nothing under 1080p here.
          qualities = [
            { name = "Bluray-1080p"; }
            { name = "WEB 1080p"; qualities = [ "WEBRip-1080p" "WEBDL-1080p" ]; }
            { name = "Bluray-720p"; enabled = false; }
          ];
        }
        {
          trash_id = remuxWeb2160p;
          reset_unmatched_scores.enabled = true;
        }
      ];

      # Default groups (HDR, audio, golden rule, general streaming services) sync
      # on their own; listed here are only the opt-ins.
      custom_format_groups.add = [
        {
          trash_id = "a3ac6af01d78e4f21fcb75f601ac96df";  # [Unwanted] Unwanted Formats
          # Private trackers only, so all three TRaSH optionals apply.
          select = [
            "ae9b7c9ebde1f3bd336a8cbd1ec4c5e5"  # No-RlsGroup
            "7357cf5161efbf8c4d5d0c30b4815ee2"  # Obfuscated
            "5c44f52a8714fdd79bb4d98e2673be1f"  # Retags
          ];
        }
        {
          trash_id = "f4f1474b963b24cf983455743aa9906c";  # [Optional] Movie Versions
          select = [
            "eca37840c13c6ef2dd0262b141a5482f"  # 4K Remaster
            "e0c07d59beb37348e975a930d5e50319"  # Criterion Collection
            "eecf3a857724171f968a66cb5719e152"  # IMAX
            "9f6cbff8cfe4ebbc1bde14c7b7bec0de"  # IMAX Enhanced
            "9d27d9d2181838f76dee150882bdc58c"  # Masters of Cinema
            "570bc9ebecd92723d2d21500f4be314c"  # Remaster
            "957d0f44b592285f26449575e8b1167e"  # Special Edition
            "db9b4c4b53d312a3ca5f1378f6440fc9"  # Vinegar Syndrome
          ];
        }
        # No TV here supports Dolby Vision: reject DV releases that have no HDR10
        # fallback, and leave DV Boost out. The TV does support HDR10+.
        { trash_id = "7fc2751eef7e6bdc70b74136e5e35c76"; assign_scores_to = uhdOnly; }  # DV (w/o HDR fallback)
        { trash_id = "b29413a7487478fe98228ce79e5689e4"; assign_scores_to = uhdOnly; }  # HDR10+ Boost
        {
          trash_id = "47f0d69750de9e16855915fa73bb7b08";  # [HDR Formats] SDR
          assign_scores_to = uhdOnly;
          # TRaSH's pick of the pair: SDR 4K WEB is still allowed, as it often
          # beats the 1080p release on bitrate alone.
          select = [ "25c12f78430a3a23413652cbd1d48d77" ];  # SDR (no WEBDL)
        }
      ];

      # TRaSH offers Hybrid on remux profiles only.
      custom_formats = [
        {
          trash_ids = [ "0f12c086e289cf966fa5948eac571f44" ];  # Hybrid
          assign_scores_to = uhdOnly;
        }
      ];
    };

    configuration.sonarr.calliope = {
      base_url = "http://127.0.0.1:8989";
      api_key._secret = config.sops.secrets."sonarr-api-key".path;

      delete_old_custom_formats = true;

      quality_definition.type = "series";

      media_management.propers_and_repacks = "do_not_prefer";

      # TVDB ids: Plex's TV agent matches on them.
      media_naming = {
        series = "plex-tvdb";
        season = "default";
        episodes = {
          rename   = true;
          standard = "default";
          daily    = "default";
          anime    = "default";
        };
      };

      quality_profiles = [
        { trash_id = web1080p; reset_unmatched_scores.enabled = true; }
        { trash_id = web2160p; reset_unmatched_scores.enabled = true; }
      ];

      custom_format_groups.add = [
        {
          trash_id = "59c3af66780d08332fdc64e68297098f";  # [Unwanted] Unwanted Formats
          select = [
            "82d40da2bc6923f41e14394075dd4b03"  # No-RlsGroup
            "e1a997ddb54e3ecbfe06341ad323c458"  # Obfuscated
            "06d66ab109d4d2eddb2794d21526d140"  # Retags
          ];
        }
        # Small bonus so a full season beats single episodes of equal quality.
        { trash_id = "d920fd959d220306888f40b6f38e1578"; }  # [Optional] Season Packs
        # Same TV choices as Radarr: no Dolby Vision, HDR10+ yes.
        { trash_id = "d776a1ea912a117d66d83b880ff2055d"; assign_scores_to = uhdOnlySonarr; }  # DV (w/o HDR fallback)
        { trash_id = "7d366c213e5c23a052b157356fac1921"; assign_scores_to = uhdOnlySonarr; }  # HDR10+ Boost
        {
          trash_id = "e1053c0ef622df3749fa43c22865663a";  # [HDR Formats] SDR
          assign_scores_to = uhdOnlySonarr;
          # 4K SDR WEB-DLs still allowed, as in Radarr; SDR WEBRips are not.
          select = [ "83304f261cf516bb208c18c54c0adf97" ];  # SDR (no WEBDL)
        }
      ];
    };
  };

  systemd.services.recyclarr.after = [ "radarr.service" "sonarr.service" ];
}
