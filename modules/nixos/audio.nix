# Audio via PipeWire, which also serves PulseAudio and ALSA clients.
{ ... }:

{
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = false;
  };
}
