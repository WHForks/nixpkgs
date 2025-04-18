{
  config,
  pkgs,
  lib,
  ...
}:
let

  cfg = config.services.riemann-dash;

  conf = pkgs.writeText "config.rb" ''
    riemann_base = "${cfg.dataDir}"
    config.store[:ws_config] = "#{riemann_base}/config/config.json"
    ${cfg.config}
  '';

  launcher = pkgs.writeScriptBin "riemann-dash" ''
    #!/bin/sh
    exec ${pkgs.riemann-dash}/bin/riemann-dash ${conf}
  '';

in
{

  options = {

    services.riemann-dash = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable the riemann-dash dashboard daemon.
        '';
      };
      config = lib.mkOption {
        type = lib.types.lines;
        description = ''
          Contents added to the end of the riemann-dash configuration file.
        '';
      };
      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/riemann-dash";
        description = ''
          Location of the riemann-base dir. The dashboard configuration file is
          is stored to this directory. The directory is created automatically on
          service start, and owner is set to the riemanndash user.
        '';
      };
    };

  };

  config = lib.mkIf cfg.enable {

    users.groups.riemanndash.gid = config.ids.gids.riemanndash;

    users.users.riemanndash = {
      description = "riemann-dash daemon user";
      uid = config.ids.uids.riemanndash;
      group = "riemanndash";
    };

    systemd.tmpfiles.settings."10-riemanndash".${cfg.dataDir}.d = {
      user = "riemanndash";
      group = "riemanndash";
    };

    systemd.services.riemann-dash = {
      wantedBy = [ "multi-user.target" ];
      wants = [ "riemann.service" ];
      after = [ "riemann.service" ];
      preStart = ''
        mkdir -p '${cfg.dataDir}/config'
      '';
      serviceConfig = {
        User = "riemanndash";
        ExecStart = "${launcher}/bin/riemann-dash";
      };
    };

  };

}
