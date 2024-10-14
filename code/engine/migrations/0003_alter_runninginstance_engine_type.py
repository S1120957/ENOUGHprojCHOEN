# Generated by Django 3.2.8 on 2023-09-20 22:51

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('engine', '0002_auto_20230920_2134'),
    ]

    operations = [
        migrations.AlterField(
            model_name='runninginstance',
            name='engine_type',
            field=models.IntegerField(choices=[(0, 'Off Chain'), (1, 'On Chain')], default=0, help_text='the on-chain engine uses the distributed ledger, while the off-chain engine uses only local data structures (mostly for testing purposes)'),
        ),
    ]
