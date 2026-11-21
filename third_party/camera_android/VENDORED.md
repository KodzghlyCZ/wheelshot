# Vendored camera_android 0.10.12

WheelShot stills need the full sensor field of view. Upstream `ResolutionPreset.max` uses a CamcorderProfile video size, which on Pixel phones is a 16:9 center crop of the 4:3 photo sensor. The viewfinder and the JPEG both look zoomed in next to the system camera at 4:3.

`ResolutionFeature` keeps that video profile for recording. When the preset is `max` it replaces capture and preview sizes with the largest JPEG and preview sizes whose aspect matches the still sensor (within 2%). A reported 16:9 active array is the video crop, so the target stays 4:3. High-resolution JPEG sizes are included. Capture is capped at a 4096px long edge so a 12MP 4:3 frame is preferred over a 50MP bin of the same field of view. Preview is capped at a 1920px long edge. If no matching size exists, the upstream video size is kept.

The Flutter Authors BSD license is in `LICENSE`.
