from django.contrib import admin
from django.utils.translation import ugettext as _
from django.utils.html import format_html
from django_object_actions import DjangoObjectActions, action
# Register your models here.

from engine.models import RunningInstance

class RunningInstanceAdmin(DjangoObjectActions, admin.ModelAdmin):

    list_display = [ "id", "label", "engine_type", "choreography", "running", ]
    list_filter = [ "engine_type", "running", ]
    search_fields = [ "id", "label", "choreography__name", "choreography__resource" ]

    fields = [ "label", "engine_type", "choreography", "running", "execution_started", "execution_ended", "rei", "automaton", "input_events", "output_events", "enforcer_states", "enforcer_buffer", ]

    readonly_fields = [ "execution_started", "execution_ended", "rei", "automaton", "enforcer_states",  "input_events", "output_events", "enforcer_buffer", ]

    change_actions = [ "action_start", "action_stop", ]
    changelist_actions = [ "action_start_all", "action_stop_all", ]


    @action(label=_("Start"), description=_("Start the current instance"))
    def action_start(self, request, obj):
        obj.start()


    @action(label=_("Start"), description=_("Start the selected instance(s)"))
    def action_start_all(self, request, queryset):
        for curr in queryset.all():
            self.action_start(request, curr)


    @action(label=_("Stop"), description=_("Stop the current instance"))
    def action_stop(self, request, obj):
        obj.stop()


    @action(label=_("Stop"), description=_("Stop the selected instance(s)"))
    def action_stop_all(self, request, queryset):
        for curr in queryset.all():
            self.action_stop(request, curr)


    def rei(self, obj : RunningInstance):
        return format_html("<pre>{}</pre>", str(obj.rei))

    def automaton(self, obj : RunningInstance):
        
        transitions = []
        for t in obj.nfa.transitions:
            #print(f"* {t}")
            t_repr = str(t)
            #print(f"+ {t_repr}")
            #print(obj.enforcer.engine)
            if obj.enforcer.engine.is_state_current(t.source):
                t_repr = f" * {t_repr}"
            else:
                t_repr = f"   {t_repr}"
            transitions.append(t_repr)

        return format_html("<pre>{}</pre>", str(obj.nfa) + "\n\nTransitions (*=enabled)" + "\n\n" + "\n".join(transitions))

    def enforcer_states(self, obj : RunningInstance):
        print(obj.enforcer)
        return format_html("<pre>{}</pre>", ", ".join(obj.enforcer_states))

    def enforcer_buffer(self, obj : RunningInstance):
        return format_html("<pre>{}</pre>", ", ".join(map(str, obj.enforcer_buffer)))

admin.site.register(RunningInstance, RunningInstanceAdmin)
