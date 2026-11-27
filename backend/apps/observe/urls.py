from django.urls import path

from . import views

app_name = "observe"

urlpatterns = [
    path("summary/", views.SummaryView.as_view(), name="summary"),
    path("report/", views.ReportView.as_view(), name="report"),
]
