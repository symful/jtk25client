/// Settings feature providers — re-exports schedule providers for class selection.
///
/// The selected class provider lives in schedule_providers.dart since it's
/// tightly coupled with the schedule feature.
library;

export '../../schedule/providers/schedule_providers.dart'
    show selectedClassProvider;
