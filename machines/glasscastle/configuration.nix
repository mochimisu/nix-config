{ config, lib, pkgs, specialArgs, inputs, ... }:

{
  environment.systemPackages = with pkgs; [
    framework-tool
  ];
}
