import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_header.dart';
import '../bloc/reminders_bloc.dart';
import '../data/reminder_model.dart';
import 'reminder_editor_page.dart';
import 'widgets/reminder_tile.dart';

/// Hour-by-hour agenda for a single day — an alternative to
/// [RemindersListPage]'s flat list, reusing the same [RemindersBloc] so
/// both views stay in sync with the same offline-first data.
class RemindersTimelinePage extends StatefulWidget {
  const RemindersTimelinePage({super.key});

  @override
  State<RemindersTimelinePage> createState() => _RemindersTimelinePageState();
}

class _RemindersTimelinePageState extends State<RemindersTimelinePage> {
  late DateTime _selectedDate = _dateOnly(DateTime.now());
  late final _scrollController = ScrollController();

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool get _isToday => _dateOnly(DateTime.now()) == _selectedDate;

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = _dateOnly(date));
    _scrollToRelevantHour();
  }

  void _scrollToRelevantHour() {
    if (!_isToday || !_scrollController.hasClients) {
      return;
    }
    // Rough estimate (no fixed item extent, since hour rows grow with the
    // reminders they hold) — good enough to land near "now" rather than at
    // the top of the day.
    _scrollController.jumpTo(
      (DateTime.now().hour * 56).toDouble().clamp(
        0,
        _scrollController.position.maxScrollExtent,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToRelevantHour(),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE d MMMM', 'fr_FR');

    return Scaffold(
      appBar: AppHeader(
        title: 'Agenda',
        subtitle: dateFormat.format(_selectedDate),
        icon: Icons.view_timeline_rounded,
        actions: [
          IconButton(
            tooltip: 'Choisir une date',
            icon: const Icon(Icons.calendar_today_rounded),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              );
              if (picked != null) {
                _selectDate(picked);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _DayStrip(selectedDate: _selectedDate, onSelected: _selectDate),
          const Divider(height: 1),
          Expanded(
            child: BlocBuilder<RemindersBloc, RemindersState>(
              builder: (context, state) {
                final remindersForDay = state.reminders.where((reminder) {
                  final due = reminder.dueAt;

                  return due.year == _selectedDate.year &&
                      due.month == _selectedDate.month &&
                      due.day == _selectedDate.day;
                }).toList()..sort((a, b) => a.dueAt.compareTo(b.dueAt));

                final byHour = <int, List<ReminderModel>>{
                  for (var hour = 0; hour < 24; hour++) hour: [],
                };
                for (final reminder in remindersForDay) {
                  byHour[reminder.dueAt.hour]!.add(reminder);
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: 24,
                  itemBuilder: (context, hour) =>
                      _HourSlot(hour: hour, reminders: byHour[hour]!),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.selectedDate, required this.onSelected});

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekdayFormat = DateFormat('E', 'fr_FR');
    final today = DateTime.now();
    // A rolling window centered on the selected date, wide enough to reach
    // it by scrolling a few days either way without a page/week jump.
    final start = selectedDate.subtract(const Duration(days: 3));

    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: 14,
        itemBuilder: (context, index) {
          final date = start.add(Duration(days: index));
          final isSelected =
              date.year == selectedDate.year &&
              date.month == selectedDate.month &&
              date.day == selectedDate.day;
          final isToday =
              date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelected(date),
              child: Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isToday && !isSelected
                      ? Border.all(color: theme.colorScheme.primary)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      weekdayFormat.format(date),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${date.day}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isSelected ? theme.colorScheme.onPrimary : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HourSlot extends StatelessWidget {
  const _HourSlot({required this.hour, required this.reminders});

  final int hour;
  final List<ReminderModel> reminders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<RemindersBloc>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: reminders.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    )
                  : Column(
                      children: reminders
                          .map(
                            (reminder) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ReminderTile(
                                reminder: reminder,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => BlocProvider.value(
                                      value: bloc,
                                      child: ReminderEditorPage(
                                        reminder: reminder,
                                      ),
                                    ),
                                  ),
                                ),
                                onToggleCompleted: () => bloc.add(
                                  ReminderCompletedToggled(reminder),
                                ),
                                onPinToggle: () =>
                                    bloc.add(ReminderPinToggled(reminder)),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
