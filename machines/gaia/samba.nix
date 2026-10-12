# File shares and the restricted Cove media identity.
# Samba passwords remain in its private database, never in the Nix store.
{...}: {
  users.groups.cove-media = {};
  users.users.cove-media = {
    isSystemUser = true;
    group = "cove-media";
    description = "Cove read-only Samba media access";
  };

  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "server string" = "gaia samba server";
        "workgroup" = "WORKGROUP";
        "map to guest" = "Bad User";
      };
      gaia = {
        path = "/earth";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "brandon";
        "force group" = "media";
        "create mask" = "0664";
        "directory mask" = "0775";
      };
      cove-transmission = {
        path = "/earth/transmission";
        browseable = "no";
        "read only" = "yes";
        "guest ok" = "no";
        "valid users" = "cove-media";
        "smb encrypt" = "required";
        "follow symlinks" = "no";
        "wide links" = "no";
      };
    };
  };
}
