/// Settings feature providers — re-exports schedule and theme providers.
///
/// The selected class provider lives in schedule_providers.dart since it's
/// tightly coupled with the schedule feature.
library;

export '../../schedule/providers/schedule_providers.dart'
    show selectedClassProvider;
export 'theme_provider.dart';
