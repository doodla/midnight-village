import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/tokens/app_colors.dart';

void main() {
  group('AppColors', () {
    group('core palette', () {
      test('voidBlack is #0D0B0F', () {
        expect(AppColors.voidBlack, const Color(0xFF0D0B0F));
      });

      test('surface is #1A1714', () {
        expect(AppColors.surface, const Color(0xFF1A1714));
      });

      test('surfaceDark is #0F0D0C', () {
        expect(AppColors.surfaceDark, const Color(0xFF0F0D0C));
      });

      test('emberRed is #B8432F', () {
        expect(AppColors.emberRed, const Color(0xFFB8432F));
      });

      test('tallowGold is #C8A24D', () {
        expect(AppColors.tallowGold, const Color(0xFFC8A24D));
      });

      test('moonSage is #5B8A72', () {
        expect(AppColors.moonSage, const Color(0xFF5B8A72));
      });

      test('parchment is #E8DFD3', () {
        expect(AppColors.parchment, const Color(0xFFE8DFD3));
      });

      test('parchmentMuted is #9C9084', () {
        expect(AppColors.parchmentMuted, const Color(0xFF9C9084));
      });

      test('outline is #3D362C', () {
        expect(AppColors.outline, const Color(0xFF3D362C));
      });
    });

    group('team colors', () {
      test('teamWerewolf is #C94038', () {
        expect(AppColors.teamWerewolf, const Color(0xFFC94038));
      });

      test('teamVillage equals tallowGold (#C8A24D)', () {
        expect(AppColors.teamVillage, const Color(0xFFC8A24D));
      });

      test('teamIndependent is #8B7D6B', () {
        expect(AppColors.teamIndependent, const Color(0xFF8B7D6B));
      });
    });

    group('phase backgrounds', () {
      test('nightBg is #0D0B0F', () {
        expect(AppColors.nightBg, const Color(0xFF0D0B0F));
      });

      test('lobbyBg is #1A1410', () {
        expect(AppColors.lobbyBg, const Color(0xFF1A1410));
      });

      test('discussionBg is #151210', () {
        expect(AppColors.discussionBg, const Color(0xFF151210));
      });

      test('votingBg is #12100E', () {
        expect(AppColors.votingBg, const Color(0xFF12100E));
      });

      test('resultsBg is #0F0D0B', () {
        expect(AppColors.resultsBg, const Color(0xFF0F0D0B));
      });
    });

    group('semantic colors', () {
      test('danger is #E05A3A', () {
        expect(AppColors.danger, const Color(0xFFE05A3A));
      });

      test('warning is #D47A3A', () {
        expect(AppColors.warning, const Color(0xFFD47A3A));
      });

      test('noDeathBlue is #6B7B8B', () {
        expect(AppColors.noDeathBlue, const Color(0xFF6B7B8B));
      });
    });
  });
}
