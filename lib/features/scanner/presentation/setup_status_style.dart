import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/scanner_enums.dart';

/// Single mapping from [SetupStatus] to its badge color — shared by the
/// setup card and the detail screen so they can never disagree.
Color setupStatusColor(SetupStatus status) => switch (status) {
      SetupStatus.pending => AppColors.warning,
      SetupStatus.approved => AppColors.success,
      SetupStatus.rejected => AppColors.error,
      SetupStatus.cancelled => AppColors.offline,
      SetupStatus.expired => AppColors.neutral,
    };
