import 'package:flutter_test/flutter_test.dart';
import 'package:wheelshot/services/app_update.dart';

void main() {
  test('parses the version line and the apk asset', () {
    final offer = parseLatestRelease(
      '''
version: 1.1.2+4

### Download

[wheelshot.apk](https://example.invalid/wheelshot.apk)
''',
      [
        {
          'name': 'wheelshot.apk',
          'browser_download_url':
              'https://github.com/KodzghlyCZ/wheelshot/releases/download/build-6/wheelshot.apk',
        },
      ],
    );
    expect(offer?.versionName, '1.1.2');
    expect(offer?.versionCode, 4);
    expect(offer?.apkUrl, contains('build-6/wheelshot.apk'));
  });

  test('ignores a release that has no version line', () {
    expect(
      parseLatestRelease('### Download\n', [
        {
          'name': 'wheelshot.apk',
          'browser_download_url': 'https://example.invalid/wheelshot.apk',
        },
      ]),
      isNull,
    );
  });

  test('only a higher version code is an update', () {
    expect(isNewerRelease(5, 4), isTrue);
    expect(isNewerRelease(4, 4), isFalse);
    expect(isNewerRelease(3, 4), isFalse);
  });
}
