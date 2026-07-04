import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/driver_schedule_service.dart';
import '../../models/driver.dart';

/// Écran de gestion des horaires d'un livreur
class DriverScheduleScreen extends StatefulWidget {
  final Driver driver;

  const DriverScheduleScreen({
    super.key,
    required this.driver,
  });

  @override
  State<DriverScheduleScreen> createState() => _DriverScheduleScreenState();
}

class _DriverScheduleScreenState extends State<DriverScheduleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<DriverScheduleService>()
          .loadDriverSchedules(widget.driver.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning Livreur'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Consumer<DriverScheduleService>(
        builder: (context, scheduleService, child) {
          final schedules =
              scheduleService.getDriverSchedules(widget.driver.id);

          if (schedules.isEmpty && !scheduleService.isLoading) {
            scheduleService.loadDriverSchedules(widget.driver.id);
          }

          if (scheduleService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              _buildDriverHeader(theme),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        'Disponibilités hebdomadaires',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...List.generate(7, (index) {
                      final dayOfWeek = index + 1;
                      final schedule = schedules.firstWhere(
                        (s) => s.dayOfWeek == dayOfWeek,
                        orElse: () => DriverSchedule(
                          id: '${widget.driver.id}_$dayOfWeek',
                          driverId: widget.driver.id,
                          dayOfWeek: dayOfWeek,
                          startTime: const TimeOfDay(hour: 9, minute: 0),
                          endTime: const TimeOfDay(hour: 21, minute: 0),
                          isAvailable: true,
                          createdAt: DateTime.now(),
                        ),
                      );

                      return _buildScheduleCard(
                          schedule, scheduleService, theme);
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<DriverScheduleService>(
          builder: (context, scheduleService, _) {
        final schedules = scheduleService.getDriverSchedules(widget.driver.id);
        return FloatingActionButton.extended(
          onPressed: () => _copyScheduleToAllDays(schedules, scheduleService),
          icon: const Icon(Icons.copy_all),
          label: const Text('Uniformiser les horaires'),
          tooltip:
              'Copier les horaires du premier jour actif sur toute la semaine',
        );
      }),
    );
  }

  Widget _buildDriverHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                widget.driver.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.driver.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.email_outlined,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.driver.email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.circle,
                        color: widget.driver.isActive
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                        size: 12),
                    const SizedBox(width: 8),
                    Text(
                      widget.driver.isActive
                          ? 'En service'
                          : 'Hors service',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(
    DriverSchedule schedule,
    DriverScheduleService scheduleService,
    ThemeData theme,
  ) {
    final dayName = scheduleService.getDayName(schedule.dayOfWeek);
    final isAvailable = schedule.isAvailable;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isAvailable ? theme.cardColor : theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAvailable
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.disabledColor.withValues(alpha: 0.1),
          width: 2,
        ),
        boxShadow: isAvailable
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.5)
                              : theme.disabledColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.calendar_today_rounded,
                          size: 20,
                          color: isAvailable
                              ? theme.colorScheme.primary
                              : theme.disabledColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        dayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isAvailable ? null : theme.disabledColor,
                        ),
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: isAvailable,
                    activeThumbColor: theme.colorScheme.primary,
                    onChanged: (value) {
                      final updated = DriverSchedule(
                        id: schedule.id,
                        driverId: schedule.driverId,
                        dayOfWeek: schedule.dayOfWeek,
                        startTime: schedule.startTime,
                        endTime: schedule.endTime,
                        isAvailable: value,
                        createdAt: schedule.createdAt,
                        updatedAt: DateTime.now(),
                      );
                      scheduleService.saveSchedule(updated);
                    },
                  ),
                ],
              ),
              if (isAvailable) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeSelector(
                        context: context,
                        label: 'Début de service',
                        time: schedule.startTime,
                        icon: Icons.wb_sunny_outlined,
                        color: Colors.orange,
                        onTimeSelected: (time) {
                          final updated = DriverSchedule(
                            id: schedule.id,
                            driverId: schedule.driverId,
                            dayOfWeek: schedule.dayOfWeek,
                            startTime: time,
                            endTime: schedule.endTime,
                            isAvailable: true,
                            createdAt: schedule.createdAt,
                            updatedAt: DateTime.now(),
                          );
                          scheduleService.saveSchedule(updated);
                        },
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward_rounded,
                          size: 16, color: Colors.grey),
                    ),
                    Expanded(
                      child: _buildTimeSelector(
                        context: context,
                        label: 'Fin de service',
                        time: schedule.endTime,
                        icon: Icons.nightlight_round,
                        color: Colors.indigo,
                        onTimeSelected: (time) {
                          final updated = DriverSchedule(
                            id: schedule.id,
                            driverId: schedule.driverId,
                            dayOfWeek: schedule.dayOfWeek,
                            startTime: schedule.startTime,
                            endTime: time,
                            isAvailable: true,
                            createdAt: schedule.createdAt,
                            updatedAt: DateTime.now(),
                          );
                          scheduleService.saveSchedule(updated);
                        },
                      ),
                    ),
                  ],
                ),
              ] else
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.disabledColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.block, size: 16, color: theme.disabledColor),
                      const SizedBox(width: 8),
                      Text(
                        'Livreur non disponible',
                        style: TextStyle(
                          color: theme.disabledColor,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSelector({
    required BuildContext context,
    required String label,
    required TimeOfDay time,
    required IconData icon,
    required Color color,
    required Function(TimeOfDay) onTimeSelected,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () async {
        final selectedTime = await showTimePicker(
          context: context,
          initialTime: time,
          builder: (context, child) {
            return Theme(
              data: theme.copyWith(
                timePickerTheme: TimePickerThemeData(
                  dialHandColor: theme.colorScheme.primary,
                ),
              ),
              child: child!,
            );
          },
        );
        if (selectedTime != null) {
          onTimeSelected(selectedTime);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.hintColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyScheduleToAllDays(
    List<DriverSchedule> schedules,
    DriverScheduleService scheduleService,
  ) {
    final sourceSchedule = schedules.firstWhere(
      (s) => s.isAvailable,
      orElse: () => schedules.isNotEmpty
          ? schedules.first
          : DriverSchedule(
              id: '${widget.driver.id}_1',
              driverId: widget.driver.id,
              dayOfWeek: 1,
              startTime: const TimeOfDay(hour: 9, minute: 0),
              endTime: const TimeOfDay(hour: 21, minute: 0),
              isAvailable: true,
              createdAt: DateTime.now(),
            ),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uniformiser les horaires ?'),
        content: Text(
            'Voulez-vous appliquer les horaires du ${scheduleService.getDayName(sourceSchedule.dayOfWeek)} '
            '(${sourceSchedule.startTime.format(context)} - ${sourceSchedule.endTime.format(context)}) '
            'à tous les autres jours de la semaine ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              for (int day = 1; day <= 7; day++) {
                final updated = DriverSchedule(
                  id: '${widget.driver.id}_$day',
                  driverId: widget.driver.id,
                  dayOfWeek: day,
                  startTime: sourceSchedule.startTime,
                  endTime: sourceSchedule.endTime,
                  isAvailable: sourceSchedule.isAvailable,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                scheduleService.saveSchedule(updated);
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text('Horaires mis à jour avec succès'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
  }
}
