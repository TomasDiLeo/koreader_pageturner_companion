enum VolumeButtonAction {
  next,
  prev,
}

extension VolumeButtonActionExtension on VolumeButtonAction {
  String get displayName {
    switch (this) {
      case VolumeButtonAction.next:
        return 'Next Page';
      case VolumeButtonAction.prev:
        return 'Previous Page';
    }
  }

  int get command {
    switch (this) {
      case VolumeButtonAction.next:
        return 1;
      case VolumeButtonAction.prev:
        return -1;
    }
  }
}