# Frigate NVR - Local Lab & Remote Access Setup

This directory contains the configuration files to run [Frigate NVR](https://frigate.video/) locally via Docker, secured by a Caddy reverse proxy, with a roadmap for secure remote access using Cloudflare Tunnels.

## 🔒 1. Local Security (Caddy Basic Auth)

Since Frigate does not have built-in authentication, we use Caddy as a reverse proxy to protect the web interface on our local network.

### Generating the Password Hash
Caddy requires a hashed password, not plaintext. Run the following Docker command to generate your bcrypt hash:

```bash
docker run --rm caddy caddy hash-password --plaintext "YOUR_SECURE_PASSWORD"
```
*Copy the output (e.g., `$2a$14$...`) and paste it into the `Caddyfile`.*

---

## 📁 2. Project Files

### `compose.yaml`
The main Docker Compose file. Notice that Frigate's web ports (`5000`, `8971`) are intentionally not exposed to the host. Only Caddy exposes port `5000` to act as the gatekeeper.

```yaml
services:
  frigate:
    image: ghcr.io/blakeblackshear/frigate:stable
    container_name: frigate
    privileged: true
    restart: unless-stopped
    shm_size: "64mb"
    ports:
      - "8554:8554" # RTSP feeds
      - "8555:8555/tcp" # WebRTC TCP
      - "8555:8555/udp" # WebRTC UDP
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./config.yaml:/config/config.yml:ro
      - ./storage:/media/frigate
      - type: tmpfs
        target: /tmp/cache
        tmpfs:
          size: 1000000000

  proxy:
    image: caddy:alpine
    container_name: caddy_proxy
    restart: unless-stopped
    ports:
      - "5000:80"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
    depends_on:
      - frigate
```

### `Caddyfile` (Example)
Rename `Caddyfile_example` to `Caddyfile` and update the credentials.

```text
:80 {
    basicauth {
        admin $2a$14$YOUR_GENERATED_HASH_HERE
    }
    reverse_proxy frigate:5000
}
```

### `config.yaml`
Optimized Frigate configuration for a local lab. Continuous recording is disabled to save disk I/O, recording only when active objects are detected.

```yaml
mqtt:
  enabled: false

cameras:
  lab_camera:
    ffmpeg:
      inputs:
        - path: rtsp://user:password@YOUR_CAMERA_IP:554/stream
          roles:
            - detect
            - record
    detect:
      width: 1280
      height: 720
      fps: 5

record:
  enabled: true
  continuous:
    days: 0
  alerts:
    retain:
      days: 3
      mode: active_objects
  detections:
    retain:
      days: 3
      mode: active_objects
```

---

## 🚀 3. Future Roadmap: Remote Access via Cloudflare Tunnels

To access Frigate from anywhere without exposing ports on the router or dealing with dynamic IPs, we will integrate Cloudflare Zero Trust (Argo Tunnels).

### Implementation Steps

1. **Create the Tunnel:**
   Log into the Cloudflare Zero Trust dashboard > **Networks** > **Tunnels**. Create a new tunnel and select Docker as the environment.

2. **Add `cloudflared` to Compose:**
   Cloudflare will provide a token. Add the following service to the `compose.yaml`:

   ```yaml
   cloudflared:
     image: cloudflare/cloudflared:latest
     container_name: cloudflared
     restart: unless-stopped
     command: tunnel run
     environment:
       - TUNNEL_TOKEN=YOUR_CLOUDFLARE_TOKEN_HERE
   ```

3. **Configure the Public Hostname:**
   In the Cloudflare dashboard, route your custom domain (e.g., `nvr.yourdomain.com`) to the local proxy container (`http://proxy:80`).

4. **Setup Zero Trust Authentication:**
   Disable Caddy's basic auth and configure a Cloudflare Access Application to require a One-Time Pin (OTP) or SSO before loading the Frigate UI.
