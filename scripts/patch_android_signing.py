#!/usr/bin/env python3
"""flutter_create로 생성된 android/app/build.gradle(.kts)에 release 서명 설정을 추가.

같은 keystore로 매번 서명해야 '업데이트'로 인식되어 기존 데이터가 보존됩니다.
key.properties 파일은 빌드 시점에 GitHub Secrets로부터 주입됩니다.
"""
import re
import sys
from pathlib import Path


def patch_kts(content: str) -> str:
    if "keystoreProperties" in content:
        return content

    imports = (
        "import java.util.Properties\n"
        "import java.io.FileInputStream\n\n"
        "val keystoreProperties = Properties()\n"
        'val keystorePropertiesFile = rootProject.file("key.properties")\n'
        "if (keystorePropertiesFile.exists()) {\n"
        "    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n"
        "}\n\n"
    )
    content = imports + content

    signing = (
        "    signingConfigs {\n"
        '        create("release") {\n'
        '            keyAlias = keystoreProperties["keyAlias"] as String?\n'
        '            keyPassword = keystoreProperties["keyPassword"] as String?\n'
        '            storeFile = keystoreProperties["storeFile"]?.let { file(it) }\n'
        '            storePassword = keystoreProperties["storePassword"] as String?\n'
        "        }\n"
        "    }\n"
    )

    content = re.sub(
        r"(\n\s*buildTypes\s*\{)",
        "\n" + signing + r"\1",
        content,
        count=1,
    )

    content = content.replace(
        'signingConfig = signingConfigs.getByName("debug")',
        'signingConfig = signingConfigs.getByName("release")',
    )
    return content


def patch_groovy(content: str) -> str:
    if "keystoreProperties" in content:
        return content

    prefix = (
        "def keystoreProperties = new Properties()\n"
        "def keystorePropertiesFile = rootProject.file('key.properties')\n"
        "if (keystorePropertiesFile.exists()) {\n"
        "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n"
        "}\n\n"
    )
    content = prefix + content

    signing = (
        "    signingConfigs {\n"
        "        release {\n"
        "            keyAlias keystoreProperties['keyAlias']\n"
        "            keyPassword keystoreProperties['keyPassword']\n"
        "            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null\n"
        "            storePassword keystoreProperties['storePassword']\n"
        "        }\n"
        "    }\n"
    )

    content = re.sub(
        r"(\n\s*buildTypes\s*\{)",
        "\n" + signing + r"\1",
        content,
        count=1,
    )

    content = content.replace(
        "signingConfig signingConfigs.debug",
        "signingConfig signingConfigs.release",
    )
    return content


def main() -> None:
    candidates = [
        Path("android/app/build.gradle.kts"),
        Path("android/app/build.gradle"),
    ]
    for path in candidates:
        if path.exists():
            content = path.read_text()
            if path.suffix == ".kts":
                content = patch_kts(content)
            else:
                content = patch_groovy(content)
            path.write_text(content)
            print(f"✅ Patched signing config in {path}")
            return
    print(
        "❌ android/app/build.gradle(.kts) not found. Run 'flutter create .' first.",
        file=sys.stderr,
    )
    sys.exit(1)


if __name__ == "__main__":
    main()
