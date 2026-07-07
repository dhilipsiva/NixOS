# Audio via PipeWire (PulseAudio disabled).
{ ... }:

{
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = false;
  };
  services.pulseaudio.enable = false;
}
