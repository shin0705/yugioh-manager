// lib/constants/card_constants.dart
// 앱 전체에서 공유하는 카드 관련 상수 및 헬퍼

import 'package:flutter/material.dart';

/// 엑스트라 덱에 들어가는 서브타입 목록
const kExtraSubTypes = {'융합', '싱크로', '엑시즈', '링크'};

bool isExtraCard(String subType) => kExtraSubTypes.contains(subType);

/// 타입별 색상 (몬스터/마법/함정)
Color typeColor(String type) {
  switch (type) {
    case '몬스터':
      return const Color(0xFFE8823A);
    case '마법':
      return const Color(0xFF22C55E);
    case '함정':
      return const Color(0xFFA855F7);
    default:
      return const Color(0xFF9BA8BC);
  }
}

Color typeBgColor(String type) {
  switch (type) {
    case '몬스터':
      return const Color(0xFFFFF4EC);
    case '마법':
      return const Color(0xFFECFDF5);
    case '함정':
      return const Color(0xFFF5F0FF);
    default:
      return const Color(0xFFF0F3F9);
  }
}

/// 서브타입(유형)별 색상 및 배경색
Color subTypeColor(String subType) {
  switch (subType) {
    case '융합':
      return const Color(0xFF9333EA); // 보라
    case '싱크로':
      return const Color(0xFF374151); // 거의 검정
    case '엑시즈':
      return const Color(0xFF1F2937); // 검정
    case '링크':
      return const Color(0xFF1D4ED8); // 파랑
    case '의식':
      return const Color(0xFF0EA5E9); // 하늘
    case '효과':
      return const Color(0xFFD97706); // 주황
    case '일반':
      return const Color(0xFF92400E); // 갈색
    default:
      return const Color(0xFF5A6A85);
  }
}

Color subTypeBgColor(String subType) {
  switch (subType) {
    case '융합':
      return const Color(0xFFF5F0FF);
    case '싱크로':
      return const Color(0xFFE5E7EB);
    case '엑시즈':
      return const Color(0xFF1F2937);
    case '링크':
      return const Color(0xFFDBEAFE);
    case '의식':
      return const Color(0xFFE0F2FE);
    case '효과':
      return const Color(0xFFFFF4EC);
    case '일반':
      return const Color(0xFFFEF3C7);
    default:
      return const Color(0xFFF0F3F9);
  }
}

Color subTypeTextColor(String subType) {
  // 엑시즈는 배경이 어두우므로 흰색 텍스트
  if (subType == '엑시즈') return Colors.white;
  return subTypeColor(subType);
}

/// 속성 색상
Color attributeColor(String attr) {
  switch (attr) {
    case '빛':
      return const Color(0xFFD97706);
    case '어둠':
      return const Color(0xFF7C3AED);
    case '불':
      return const Color(0xFFDC2626);
    case '물':
      return const Color(0xFF2563EB);
    case '땅':
      return const Color(0xFF92400E);
    case '바람':
      return const Color(0xFF0D9488);
    case '신':
      return const Color(0xFFD97706);
    default:
      return const Color(0xFF9BA8BC);
  }
}

Color attributeBgColor(String attr) {
  switch (attr) {
    case '빛':
      return const Color(0xFFFEF3C7);
    case '어둠':
      return const Color(0xFFEDE9FE);
    case '불':
      return const Color(0xFFFEE2E2);
    case '물':
      return const Color(0xFFDBEAFE);
    case '땅':
      return const Color(0xFFFEF3C7);
    case '바람':
      return const Color(0xFFCCFBF1);
    case '신':
      return const Color(0xFFFEF3C7);
    default:
      return const Color(0xFFF0F3F9);
  }
}

/// 영문 종족 → 한글 매핑 (마법/함정 race 제거용)
const kRaceMap = {
  'Aqua': '수족',
  'Beast': '야수족',
  'Beast-Warrior': '야수전사족',
  'Creator God': '창조신족',
  'Cyberse': '사이버스족',
  'Dinosaur': '공룡족',
  'Divine-Beast': '환신야수족',
  'Dragon': '드래곤족',
  'Fairy': '천사족',
  'Fiend': '악마족',
  'Fish': '어류족',
  'Illusion': '환상마족',
  'Insect': '곤충족',
  'Machine': '기계족',
  'Plant': '식물족',
  'Psychic': '사이킥족',
  'Pyro': '화염족',
  'Reptile': '파충류족',
  'Rock': '암석족',
  'Sea Serpent': '해룡족',
  'Spellcaster': '마법사족',
  'Thunder': '번개족',
  'Warrior': '전사족',
  'Winged Beast': '비행야수족',
  'Wyrm': '환룡족',
  'Zombie': '언데드족',
};

/// API에서 넘어오는 마법/함정 race 값 → 유형으로 변환
const kSpellRaceToSubType = {
  'Normal': '일반',
  'Continuous': '지속',
  'Quick-Play': '속공',
  'Equip': '장착',
  'Field': '필드',
  'Ritual': '의식',
  'Counter': '카운터',
};

/// 마법/함정 race를 서브타입으로 변환 (해당 없으면 null)
String? raceToSubType(String race) => kSpellRaceToSubType[race];

/// 한글 종족 목록 (드롭다운용)
const kRaceOptions = [
  '드래곤족', '마법사족', '언데드족', '전사족', '야수전사족', '야수족',
  '비행야수족', '천사족', '악마족', '곤충족', '공룡족', '파충류족',
  '물고기족', '해룡족', '수족', '화염족', '기계족', '암석족', '식물족',
  '번개족', '사이킥족', '사이버스족', '환신야수족', '창조신족', '환룡족',
  '환상마족', '야수전사족',
];
