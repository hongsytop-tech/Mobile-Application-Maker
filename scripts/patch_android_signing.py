#!/usr/bin/env python3
"""flutter_create로 생성된 android/app/build.gradle(.kts)에 release 서명 설정을 추가.

Gradle 7.6+ 규칙상 plugins {} 블록 앞에는 buildscript/pluginManagement 외 어떤 statement도
올 수 없으므로, keystoreProperties 선언은 반드시 plugins 블록 뒤에 삽입한다.

같은 keystore로 매번 서명해야 안드로이드가 '업데이트'로 인식해 기존 데이터를 보존한다.
key.properties는 빌드 시 GitHub Secrets로부터 주입된다.
"""
import re
import sys
from pathlib import Path


def find_plugins_block_end(content: str) -> int | None:
    """plugins {} 블록의 닫는 brace 바로 다음 위치를 반환 (없으면 None)."""
    m = re.search(r"\bplugins\s*\{", content)
    if not m:
        return None
    depth = 1
    i = m.end()
    while i < len(content) and depth > 0:
        c = content[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        i += 1
    return i if depth == 0 else None


def insert_after_plugins(content: str, code: str) -> str:
    end = find_plugins_block_end(content)
    if end is None:
        # plugins 블록이 없으면 그냥 앞에 붙임 (드물지만 안전 폴백)
        return code + content
    return content[:end] + "\n\n" + code + content[end:]


def patch_kts(content: str) -> str:
    if "keystoreProperties" in content:
        return content

    # Kotlin은 import가 파일 최상단에 와야 하지만, plugins 블록 자체는 imports 뒤에 둘 수 있음.
    # 안전하게 plugins 뒤에 import + 선언 모두 넣되, import는 KTS에선 plugins 블록 뒤에도 허용됨.
    # 단, 깔끔하게 하기 위해 fully-qualified 클래스명을 사용해 import 생략.
    keystore_block = (
        "val keystoreProperties = java.util.Properties()\n"
        'val keystorePropertiesFile = rootProject.file("key.properties")\n'
        "if (keystorePropertiesFile.exists()) {\n"
        "    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))\n"
        "}\n"
    )

    content = insert_after_plugins(content, keystore_block)

    signing_block = (
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
        "\n" + signing_block + r"\1",
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

    keystore_block = (
        "def keystoreProperties = new Properties()\n"
        "def keystorePropertiesFile = rootProject.file('key.properties')\n"
        "if (keystorePropertiesFile.exists()) {\n"
        "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n"
        "}\n"
    )

    content = insert_after_plugins(content, keystore_block)

    signing_block = (
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
        "\n" + signing_block + r"\1",
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
            original = path.read_text()
            if path.suffix == ".kts":
                patched = patch_kts(original)
            else:
                patched = patch_groovy(original)
            path.write_text(patched)
            print(f"✅ Patched signing config in {path}")
            return
    print(
        "❌ android/app/build.gradle(.kts) not found. Run 'flutter create .' first.",
        file=sys.stderr,
    )
    sys.exit(1)


if __name__ == "__main__":
    main()
