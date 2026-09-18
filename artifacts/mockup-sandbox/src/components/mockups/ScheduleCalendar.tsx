import { useMemo, useState } from "react";

type Assessment = { id: string; subject_employee_id: string; cycle_id: string; created_at: string };
type Checkin = { id: string; employee_id: string; checkin_date: string; mood: number; engagement: number; energy: number; workload: number; note?: string | null; created_at: string };

type ScheduleCalendarProps = {
  assessments: Assessment[];
  checkins: Checkin[];
  employeeNames: Map<string, string>;
  cycleNames: Map<string, string>;
  onAssessmentClick: (id: string) => void;
  onCheckinClick: (id: string) => void;
};

type CalendarEvent = {
  id: string;
  kind: "assessment" | "checkin";
  date: string;
  title: string;
  subtitle: string;
};

const WEEKDAYS = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"];
const MONTHS = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];

function toDateKey(value: string): string {
  return value.slice(0, 10);
}

export default function ScheduleCalendar({ assessments, checkins, employeeNames, cycleNames, onAssessmentClick, onCheckinClick }: ScheduleCalendarProps) {
  const [currentMonth, setCurrentMonth] = useState(() => {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), 1);
  });
  const [selectedDate, setSelectedDate] = useState<string | null>(null);

  const events = useMemo<CalendarEvent[]>(() => {
    const assessmentEvents: CalendarEvent[] = assessments.map((a) => ({
      id: a.id,
      kind: "assessment" as const,
      date: toDateKey(a.created_at),
      title: employeeNames.get(a.subject_employee_id) ?? "Pessoa da equipe",
      subtitle: cycleNames.get(a.cycle_id) ?? "Avaliação",
    }));
    const checkinEvents: CalendarEvent[] = checkins.map((c) => ({
      id: c.id,
      kind: "checkin" as const,
      date: c.checkin_date,
      title: employeeNames.get(c.employee_id) ?? "Pessoa da equipe",
      subtitle: `Clima ${c.mood}/5 · Engajamento ${c.engagement}/5`,
    }));
    return [...assessmentEvents, ...checkinEvents];
  }, [assessments, checkins, employeeNames, cycleNames]);

  const eventsByDate = useMemo(() => {
    const map = new Map<string, CalendarEvent[]>();
    for (const event of events) {
      const list = map.get(event.date) ?? [];
      list.push(event);
      map.set(event.date, list);
    }
    return map;
  }, [events]);

  const monthEvents = useMemo(() => {
    const year = currentMonth.getFullYear();
    const month = currentMonth.getMonth();
    return events.filter((event) => {
      const date = new Date(`${event.date}T12:00:00`);
      return date.getFullYear() === year && date.getMonth() === month;
    });
  }, [events, currentMonth]);

  const days = useMemo(() => {
    const year = currentMonth.getFullYear();
    const month = currentMonth.getMonth();
    const firstDay = new Date(year, month, 1);
    const startOffset = firstDay.getDay();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const cells: Array<{ date: string | null; dayNumber: number; isToday: boolean }> = [];
    for (let i = 0; i < startOffset; i++) cells.push({ date: null, dayNumber: 0, isToday: false });
    const todayKey = new Date().toISOString().slice(0, 10);
    for (let day = 1; day <= daysInMonth; day++) {
      const dateKey = `${year}-${String(month + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
      cells.push({ date: dateKey, dayNumber: day, isToday: dateKey === todayKey });
    }
    return cells;
  }, [currentMonth]);

  const selectedEvents = selectedDate ? (eventsByDate.get(selectedDate) ?? []) : [];

  function goToPreviousMonth() {
    setCurrentMonth((prev) => new Date(prev.getFullYear(), prev.getMonth() - 1, 1));
    setSelectedDate(null);
  }

  function goToNextMonth() {
    setCurrentMonth((prev) => new Date(prev.getFullYear(), prev.getMonth() + 1, 1));
    setSelectedDate(null);
  }

  function goToToday() {
    const now = new Date();
    setCurrentMonth(new Date(now.getFullYear(), now.getMonth(), 1));
    setSelectedDate(now.toISOString().slice(0, 10));
  }

  return (
    <div>
      {/* Legend */}
      <div className="mb-4 flex flex-wrap items-center gap-4">
        <span className="flex items-center gap-2 text-sm font-semibold text-slate-600">
          <span className="h-3 w-3 rounded-full bg-amber-400" /> Avaliações
        </span>
        <span className="flex items-center gap-2 text-sm font-semibold text-slate-600">
          <span className="h-3 w-3 rounded-full bg-[#2aa6a0]" /> Check-ins
        </span>
      </div>

      {/* Calendar header */}
      <div className="mb-4 flex items-center justify-between gap-3">
        <h3 className="text-lg font-extrabold text-slate-900">{MONTHS[currentMonth.getMonth()]} {currentMonth.getFullYear()}</h3>
        <div className="flex items-center gap-2">
          <button className="ag-btn-sec rounded-xl px-3 py-2 text-sm font-bold text-slate-600 transition hover:border-[#2aa6a0]/40" onClick={goToPreviousMonth} type="button">‹</button>
          <button className="ag-btn-sec rounded-xl px-3 py-2 text-sm font-bold text-slate-600 transition hover:border-[#2aa6a0]/40" onClick={goToToday} type="button">Hoje</button>
          <button className="ag-btn-sec rounded-xl px-3 py-2 text-sm font-bold text-slate-600 transition hover:border-[#2aa6a0]/40" onClick={goToNextMonth} type="button">›</button>
        </div>
      </div>

      {/* Calendar grid */}
      <div className="ag-glass overflow-hidden rounded-2xl">
        <div className="grid grid-cols-7 border-b border-white/20 bg-white/20">
          {WEEKDAYS.map((weekday) => (
            <div key={weekday} className="px-1 py-2.5 text-center text-xs font-bold uppercase tracking-wide text-slate-500">{weekday}</div>
          ))}
        </div>
        <div className="grid grid-cols-7">
          {days.map((cell, index) => {
            if (!cell.date) return <div key={`empty-${index}`} className="min-h-[64px] border-b border-r border-white/10 bg-white/5 sm:min-h-[88px]" />;
            const dayEvents = eventsByDate.get(cell.date) ?? [];
            const hasAssessment = dayEvents.some((event) => event.kind === "assessment");
            const hasCheckin = dayEvents.some((event) => event.kind === "checkin");
            const isSelected = selectedDate === cell.date;
            return (
              <button
                key={cell.date}
                className={`flex min-h-[64px] flex-col items-start gap-1 border-b border-r border-white/10 p-1.5 text-left transition sm:min-h-[88px] sm:p-2 ${
                  isSelected ? "bg-[#2aa6a0]/15 ring-2 ring-inset ring-[#2aa6a0]/50" : cell.isToday ? "bg-[#2aa6a0]/8" : "hover:bg-white/20"
                }`}
                onClick={() => setSelectedDate(cell.date)}
                type="button"
              >
                <span className={`flex h-6 w-6 items-center justify-center rounded-full text-xs font-bold ${
                  cell.isToday ? "bg-[#2aa6a0] text-white" : "text-slate-700"
                }`}>{cell.dayNumber}</span>
                <div className="flex flex-wrap gap-1">
                  {hasAssessment && <span className="h-2.5 w-2.5 rounded-full bg-amber-400" />}
                  {hasCheckin && <span className="h-2.5 w-2.5 rounded-full bg-[#2aa6a0]" />}
                </div>
                {dayEvents.length > 0 && (
                  <span className="hidden text-[10px] font-semibold text-slate-400 sm:block">{dayEvents.length} evento{dayEvents.length > 1 ? "s" : ""}</span>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* Selected day events */}
      {selectedDate && (
        <div className="ag-glass mt-6 rounded-2xl p-5">
          <h4 className="font-bold text-slate-800">
            {new Intl.DateTimeFormat("pt-BR", { day: "2-digit", month: "long", year: "numeric" }).format(new Date(`${selectedDate}T12:00:00`))}
          </h4>
          {selectedEvents.length === 0 ? (
            <p className="mt-3 text-sm text-slate-500">Nenhum evento neste dia.</p>
          ) : (
            <div className="mt-4 space-y-3">
              {selectedEvents.map((event) => (
                <div
                  key={`${event.kind}-${event.id}`}
                  className="ag-glass-muted flex cursor-pointer items-center gap-3 rounded-xl p-3 transition hover:shadow-md"
                  onClick={() => event.kind === "assessment" ? onAssessmentClick(event.id) : onCheckinClick(event.id)}
                >
                  <span className={`flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-full text-white ${event.kind === "assessment" ? "bg-amber-400" : "bg-[#2aa6a0]"}`}>
                    {event.kind === "assessment" ? "★" : "♥"}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-bold text-slate-800">{event.title}</p>
                    <p className="truncate text-xs text-slate-500">{event.subtitle}</p>
                  </div>
                  <span className={`rounded-full px-2 py-1 text-[11px] font-bold ${event.kind === "assessment" ? "bg-amber-50 text-amber-700" : "bg-teal-50 text-teal-700"}`}>
                    {event.kind === "assessment" ? "Avaliação" : "Check-in"}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Month summary */}
      <div className="mt-6 grid gap-4 sm:grid-cols-3">
        <div className="ag-glass rounded-2xl p-5">
          <p className="text-sm text-slate-500">Eventos no mês</p>
          <p className="mt-2 text-2xl font-extrabold text-[#102654]">{monthEvents.length}</p>
        </div>
        <div className="ag-glass rounded-2xl p-5">
          <p className="text-sm text-slate-500">Avaliações</p>
          <p className="mt-2 text-2xl font-extrabold text-amber-600">{monthEvents.filter((event) => event.kind === "assessment").length}</p>
        </div>
        <div className="ag-glass rounded-2xl p-5">
          <p className="text-sm text-slate-500">Check-ins</p>
          <p className="mt-2 text-2xl font-extrabold text-[#2aa6a0]">{monthEvents.filter((event) => event.kind === "checkin").length}</p>
        </div>
      </div>
    </div>
  );
}
