# Third-party notices

ScanMarket распространяется вместе с Qode Runtime и набором сторонних
библиотек. Ниже перечислены компоненты, их версии и условия распространения.

Полные тексты лицензий находятся в каталоге `LICENSES/`.

## Qode Runtime (собственный компонент, MIT)

| Компонент | Пути |
| --- | --- |
| Qode Runtime (движок Script/Qode) | `bin/qode.exe`, `bin/qodeqt.exe`, `bin/qodegui.exe`, `bin/qodedesigner.exe` |
| Плагины Qode | `bin/plugins/*.dll` |
| Локализация дизайнера | `bin/translations/qodedesigner_RU.qm` |

Qode Runtime — собственный компонент проекта и распространяется на тех же
условиях, что и весь ScanMarket, по лицензии MIT (`LICENSE`). Исходный код
ядра Qode публикуется в репозитории по мере готовности; скомпилированная
среда выполнения уже входит в поставку.

## Qt 6.11.2 — The Qt Company (LGPL v3)

| Компонент | Пути |
| --- | --- |
| Qt Core | `bin/Qt6Core.dll`, `bin/Qt6Core5Compat.dll` |
| Qt GUI | `bin/Qt6Gui.dll` |
| Qt Network | `bin/Qt6Network.dll` |
| Qt Pdf | `bin/Qt6Pdf.dll` |
| Qt Print Support | `bin/Qt6PrintSupport.dll` |
| Qt Sql | `bin/Qt6Sql.dll` |
| Qt Svg | `bin/Qt6Svg.dll`, `bin/Qt6SvgWidgets.dll` |
| Qt Widgets | `bin/Qt6Widgets.dll` |
| Qt Platform Plugins | `bin/platforms/qwindows.dll`, `bin/platforms/qoffscreen.dll` |
| Qt Image Formats | `bin/imageformats/*.dll` |
| Qt SQL Drivers | `bin/sqldrivers/*.dll` |
| Qt Styles | `bin/styles/qmodernwindowsstyle.dll` |
| Qt TLS Backends | `bin/tls/*.dll` |
| Qt Icon Engines | `bin/iconengines/qsvgicon.dll` |
| Qt Generic Plugins | `bin/generic/qtuiotouchplugin.dll` |
| Qt Network Information | `bin/networkinformation/qnetworklistmanager.dll` |
| Qt Translations | `bin/translations/qt_*.qm` |

Qt распространяется по лицензии **GNU Lesser General Public License v3**
(LGPL v3). Динамическое связывание с Qt DLL разрешено при условии
распространения текста лицензии и возможности пользователя заменить
библиотеки. Текст лицензии: `LICENSES/LGPL-3.0.txt`.

Исходный код Qt доступен на <https://code.qt.io/> и через дистрибутивы Qt.
Для замены DLL достаточно поместить в `bin/` версию, совместимую по ABI.

## OpenSSL 3.5.4 — The OpenSSL Project (Apache 2.0)

| Компонент | Путь |
| --- | --- |
| libcrypto | `bin/libcrypto-3-x64.dll` |
| libssl | `bin/libssl-3-x64.dll` |

OpenSSL распространяется по лицензии **Apache License 2.0**.
Текст лицензии: `LICENSES/Apache-2.0.txt`.

## LLVM libc++ и libunwind (Apache 2.0 + LLVM Exception)

| Компонент | Путь |
| --- | --- |
| libc++ | `bin/libc++.dll` |
| libunwind | `bin/libunwind.dll` |

Библиотеки из проекта LLVM распространяются по **Apache License 2.0** с
исключением LLVM (LLVM Exceptions). Тексты: `LICENSES/Apache-2.0.txt` и
`LICENSES/LLVM-exceptions.txt`.

## Mesa llvmpipe (opengl32sw.dll) — MIT

| Компонент | Путь |
| --- | --- |
| Программный OpenGL (llvmpipe) | `bin/opengl32sw.dll` |

Распространяется по лицензии **MIT**.
Текст лицензии: `LICENSES/MIT.txt`.

## D3Dcompiler_47.dll — Microsoft

| Компонент | Путь |
| --- | --- |
| DirectX Shader Compiler | `bin/D3Dcompiler_47.dll` |

Компонент принадлежит Microsoft и входит в состав системы или
распространительных наборов Microsoft. Распространение разрешено в составе
приложения согласно условиям Microsoft.

## Дистрибутивы Microsoft (вне поставки)

Изначально в проекте присутствовал каталог `Redist/` с распространительными
компонентами Microsoft (Visual C++ Redistributable, драйверы ODBC для SQL
Server, PostgreSQL ODBC). В публичную поставку эти файлы не входят. При
необходимости пользователь может скачать их из официальных источников
Microsoft и проекта PostgreSQL.

| Файл | Назначение | Лицензия |
| --- | --- | --- |
| `VC_redist.x64.exe` | Visual C++ Runtime | Microsoft (распространительная лицензия) |
| `msodbcsql.msi` | Microsoft ODBC Driver for SQL Server | Microsoft (распространительная лицензия) |
| `msoledbsql_x64.msi` | Microsoft OLE DB Driver for SQL Server | Microsoft (распространительная лицензия) |
| `sqlncli_x64.msi` | SQL Server Native Client | Microsoft (распространительная лицензия) |
| `psqlodbc_x64.msi` | PostgreSQL ODBC Driver | PostgreSQL License |

## Итог

Проект ScanMarket (скрипты, библиотеки, Qode Runtime, документация)
распространяется по лицензии MIT (`LICENSE`). Сторонние компоненты остаются
под собственными лицензиями, перечисленными выше.
