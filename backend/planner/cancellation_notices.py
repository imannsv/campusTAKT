"""Cancellation notices use the same frozen audience and details as the student feed."""

from collections import defaultdict

from . import models as m
from .overview import enrich_snapshot
from .services import local
from .student_push import queue_notice_push


def notify_cancellations(institution, sessions):
    by_plan = defaultdict(set)
    for session in sessions:
        by_plan[session.plan_id].add(session.id)
    for plan_id, session_ids in by_plan.items():
        publication = (
            m.Publication.objects.filter(
                institution=institution,
                plan_id=plan_id,
                plan__institution=institution,
            )
            .order_by("-number")
            .first()
        )
        if publication is None:
            continue
        rows = enrich_snapshot(publication.snapshot, institution.id)
        for row in rows:
            if row["id"] not in session_ids or row.get("cancelled"):
                continue
            group_ids = {group["id"] for group in row["overview_scope"]["groups"]}
            groups = m.Group.objects.filter(institution=institution, id__in=group_ids)
            start, end = (
                local(row["start"], institution),
                local(row["end"], institution),
            )
            end_label = end.strftime(
                "%H:%M" if start.date() == end.date() else "%d.%m.%Y %H:%M"
            )
            rooms = ", ".join(row.get("room_names", [])) or "Nicht angegeben"
            body = (
                f"Die folgende Veranstaltung entfällt:\n\n{row['name']}\n"
                f"{start:%d.%m.%Y}, {start:%H:%M}–{end_label} Uhr\nRaum: {rooms}\n\n"
                "Der Termin bleibt im Stundenplan als entfallen sichtbar."
            )
            for group in groups:
                notice, created = m.StudentNotice.objects.get_or_create(
                    institution=institution,
                    cancellation_session_id=row["id"],
                    group=group,
                    active=True,
                    defaults={
                        "title": f"Termin entfällt: {row['name']}"[:160],
                        "body": body,
                    },
                )
                if created:
                    queue_notice_push(notice)
