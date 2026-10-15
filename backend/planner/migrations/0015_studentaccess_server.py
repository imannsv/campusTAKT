from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("planner", "0014_studentnotice_cancellation_session")]

    operations = [
        migrations.AddField(
            model_name="studentaccess",
            name="server",
            field=models.URLField(blank=True, default="", max_length=500),
        ),
    ]
