import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// 사람 칸(`a`, `b`)의 색. 칸에 고정이라 두 폰에서 같은 사람이 늘 같은 색이다.
Color personColor(String key) => key == 'b' ? AppColors.personB : AppColors.personA;
