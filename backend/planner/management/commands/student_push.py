import logging
import time

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import close_old_connections

from planner.student_push import deliver_pending_pushes, provider_token, push_configured

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = "Deliver queued student notifications to APNs."

    def add_arguments(self, parser):
        parser.add_argument("--watch", action="store_true")

    def handle(self, *args, **options):
        # APNs URLs contain device tokens; suppress HTTP client's request logging.
        logging.getLogger("httpx").setLevel(logging.WARNING)
        logging.getLogger("httpcore").setLevel(logging.WARNING)
        if not push_configured():
            raise CommandError(
                "APNS_ENABLED, TEAM_ID, KEY_ID, KEY_PATH, TOPIC und ENVIRONMENT prüfen."
            )
        try:
            provider_token(
                settings.APNS_TEAM_ID,
                settings.APNS_KEY_ID,
                settings.APNS_KEY_PATH,
                int(time.time()) // 1200,
            )
        except Exception:
            raise CommandError(
                "APNs-Signierschlüssel kann nicht geladen werden. Datei und ES256-Schlüssel prüfen."
            ) from None
        self.stdout.write("CampusZeit Push-Dienst bereit.")
        while True:
            try:
                close_old_connections()
                count = deliver_pending_pushes()
            except KeyboardInterrupt:
                return
            except Exception:
                if not options["watch"]:
                    raise CommandError(
                        "Push-Durchlauf fehlgeschlagen; Datenbank und Konfiguration prüfen."
                    ) from None
                logger.error(
                    "Push-Durchlauf fehlgeschlagen; erneuter Versuch in fünf Sekunden."
                )
                count = 0
            finally:
                close_old_connections()
            if not options["watch"]:
                self.stdout.write(f"{count} Zustellversuche abgeschlossen.")
                return
            try:
                time.sleep(5)
            except KeyboardInterrupt:
                return
