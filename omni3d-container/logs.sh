#!/bin/bash
# logs.sh
# Tails logs for all services or a specific one.
# Usage:
#   ./logs.sh               — supervisord main log
#   ./logs.sh update        — update-service stdout
#   ./logs.sh rfid          — rfid-middleware stdout
#   ./logs.sh counters      — work-time-counters stdout
#   ./logs.sh timelapse     — timelapse stdout
#   ./logs.sh all           — all service logs interleaved

CONTAINER="omni3d-stack"
SERVICE="${1:-}"

case "$SERVICE" in
    update)    docker exec "$CONTAINER" tail -f /var/log/update-service.log ;;
    rfid)      docker exec "$CONTAINER" tail -f /var/log/rfid-middleware.log ;;
    counters)  docker exec "$CONTAINER" tail -f /var/log/work-time-counters.log ;;
    timelapse) docker exec "$CONTAINER" tail -f /var/log/timelapse.log ;;
    all)
        # interleave all logs with service name prefix
        docker exec "$CONTAINER" bash -c "
            tail -f \
                /var/log/update-service.log \
                /var/log/rfid-middleware.log \
                /var/log/work-time-counters.log \
                /var/log/timelapse.log
        "
        ;;
    *)
        # default — supervisord log + service status
        echo "── Service status ──"
        docker exec "$CONTAINER" supervisorctl status
        echo ""
        echo "── Supervisord log ──"
        docker exec "$CONTAINER" tail -f /var/log/supervisord.log
        ;;
esac
