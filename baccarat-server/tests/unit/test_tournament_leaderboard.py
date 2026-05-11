"""Тесты leaderboard турниров: выбор лучшей попытки и shared rank."""

from datetime import datetime, timedelta, timezone

from app.api.tournaments import (
    build_tournament_leaderboard_entries,
    get_best_success_attempt_for_participant,
    get_tournament_leaderboard_rows,
)
from app.models.tournament import Tournament, TournamentStatus, default_tournament_settings
from app.models.tournament_attempt import TournamentAttempt, TournamentAttemptStatus
from app.models.tournament_participant import TournamentParticipant
from app.models.trainer import Trainer


class TestTournamentLeaderboard:
    async def test_best_attempt_and_shared_rank(self, db_session):
        trainer = Trainer(
            email="leaderboard@trainer.com",
            password_hash="hash",
            full_name="Leaderboard Trainer",
            is_active=True,
        )
        db_session.add(trainer)
        await db_session.flush()

        tournament = Tournament(
            trainer_id=trainer.id,
            title="Leaderboard Tournament",
            code="LEAD-001",
            status=TournamentStatus.ACTIVE,
            max_rounds=50,
            attempt_duration_seconds=600,
            tournament_settings=default_tournament_settings(),
        )
        db_session.add(tournament)
        await db_session.flush()

        participant_1 = TournamentParticipant(
            tournament_id=tournament.id,
            display_name="Alice",
            normalized_display_name="alice",
        )
        participant_2 = TournamentParticipant(
            tournament_id=tournament.id,
            display_name="Bob",
            normalized_display_name="bob",
        )
        participant_3 = TournamentParticipant(
            tournament_id=tournament.id,
            display_name="Charlie",
            normalized_display_name="charlie",
        )
        db_session.add_all([participant_1, participant_2, participant_3])
        await db_session.flush()

        base_time = datetime.now(timezone.utc)
        db_session.add_all(
            [
                TournamentAttempt(
                    tournament_id=tournament.id,
                    tournament_participant_id=participant_1.id,
                    attempt_number=1,
                    status=TournamentAttemptStatus.SUCCESS,
                    finish_reason="round_limit",
                    rounds_completed=8,
                    errors_total=1,
                    time_spent_seconds=100,
                    submitted_at=base_time,
                ),
                TournamentAttempt(
                    tournament_id=tournament.id,
                    tournament_participant_id=participant_1.id,
                    attempt_number=2,
                    status=TournamentAttemptStatus.SUCCESS,
                    finish_reason="round_limit",
                    rounds_completed=10,
                    errors_total=3,
                    time_spent_seconds=120,
                    submitted_at=base_time + timedelta(seconds=1),
                ),
                TournamentAttempt(
                    tournament_id=tournament.id,
                    tournament_participant_id=participant_2.id,
                    attempt_number=1,
                    status=TournamentAttemptStatus.SUCCESS,
                    finish_reason="round_limit",
                    rounds_completed=10,
                    errors_total=3,
                    time_spent_seconds=120,
                    submitted_at=base_time + timedelta(seconds=2),
                ),
                TournamentAttempt(
                    tournament_id=tournament.id,
                    tournament_participant_id=participant_3.id,
                    attempt_number=1,
                    status=TournamentAttemptStatus.SUCCESS,
                    finish_reason="round_limit",
                    rounds_completed=10,
                    errors_total=2,
                    time_spent_seconds=150,
                    submitted_at=base_time + timedelta(seconds=3),
                ),
                TournamentAttempt(
                    tournament_id=tournament.id,
                    tournament_participant_id=participant_3.id,
                    attempt_number=2,
                    status=TournamentAttemptStatus.FAILED,
                    finish_reason="manual_exit",
                    rounds_completed=20,
                    errors_total=0,
                    time_spent_seconds=30,
                    submitted_at=base_time + timedelta(seconds=4),
                ),
            ]
        )
        await db_session.commit()

        best_attempt_p1 = await get_best_success_attempt_for_participant(participant_1.id, db_session)
        assert best_attempt_p1 is not None
        assert int(best_attempt_p1.attempt_number) == 2
        assert int(best_attempt_p1.rounds_completed) == 10

        rows = await get_tournament_leaderboard_rows(tournament.id, db_session)
        entries = build_tournament_leaderboard_entries(rows)

        assert [entry.display_name for entry in entries] == ["Charlie", "Alice", "Bob"]
        assert [int(entry.rounds_completed) for entry in entries] == [10, 10, 10]
        assert [int(entry.errors_total) for entry in entries] == [2, 3, 3]
        assert [int(entry.time_spent_seconds) for entry in entries] == [150, 120, 120]
        assert [int(entry.rank) for entry in entries] == [1, 2, 2]
