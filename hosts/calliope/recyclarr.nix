{ config, ... }:

# Recyclarr syncs TRaSH Guides' quality profiles, custom formats, file-size
# limits and naming into Radarr, daily. Everything it manages is overwritten
# on each run, so change those settings here rather than in the Radarr UI.
#
# Two profiles, chosen per movie (one copy each, no separate 4K instance):
#   HD Bluray + WEB    1080p encodes; 720p disabled, never anything lower
#   Remux + WEB 2160p  4K remuxes, with audio formats for HD passthrough
#
# trash_ids come from the TRaSH-Guides repo (docs/json/radarr/), and the
# group/select layout mirrors recyclarr's config-templates for these profiles.

let
  hdBlurayWeb   = "d1d67249d3890e49bc12e275d989a7e9";  # HD Bluray + WEB
  remuxWeb2160p = "fd161a61e3ab826d3a22d53f935696dd";  # Remux + WEB 2160p

  uhdOnly = [ { trash_id = remuxWeb2160p; } ];
in
{
  # api_key reads radarr.nix's radarr-api-key, the same secret Radarr's APIKEY
  # is templated from, so the two can never disagree.
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
  };

  systemd.services.recyclarr.after = [ "radarr.service" ];
}
