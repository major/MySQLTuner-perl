---
description: /docker-clean
---

---

description: Reclaim disk space by removing unused containers and images
---

1. **Check Current Usage**:
   - See how much space Docker is using.
   // turbo
   - Run `docker system df`

2. **Run Prune**:
   - ⚠️ **WARNING**: This will remove all stopped containers and unused images!
   - Remove all stopped containers, unused networks, and dangling images.
   // turbo
   - Run `docker system prune -a`

3. **Verify Space Reclaimed**:
   - Check the new disk usage.
   // turbo
   - Run `docker system df`

4. **Pro Tips**:
   - Add `--volumes` to also delete unused volumes (DATA LOSS WARNING!).
   - To remove only dangling images: `docker image prune`.
   - Set up automatic cleanup: add `"log-opts": {"max-size": "10m"}` to Docker daemon config.
