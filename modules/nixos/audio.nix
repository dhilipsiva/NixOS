# Audio via PipeWire (PulseAudio disabled).
{ ... }:

{
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = false;
  };
  services.pulseaudio.enable = false;
}
