from django.contrib import admin

from bpmn_parser.models import Choreography

class ChoreographyAdmin(admin.ModelAdmin):

    list_display = [ "id", "name", "resource", ]
    search_fields = [ "id", "name", "resource", ]


admin.site.register(Choreography, ChoreographyAdmin)
