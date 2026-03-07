## Compressing screen recording videos

Screen recordings of IDEs compress very well. Use ffmpeg to re-encode:

```
ffmpeg -i input.mp4 -vf "scale=1280:720,fps=15" -c:v libx264 -crf 30 -preset slow -an output.mp4
```

This scales to 720p, drops to 15fps, and uses a higher CRF for smaller files. Typically reduces file size by ~95% with no perceptible quality loss for IDE recordings.
