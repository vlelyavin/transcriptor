# Transcriptor — батч правок #2 (вечер 03.10.2026)

Источник: сообщения Вовы от 03.10.2026 ~19:00–19:20. Идти по порядку, по каждому пункту — фикс + проверка.

1. [ ] Шапка/toolbar: фон появляется сразу на некоторых страницах. Эталон — Overview (прозрачно сверху, фон при скролле). Найти, чем страницы отличаются (Form vs ScrollView), сделать как Overview везде.
2. [ ] Фильтр моделей: убрать sticky — вернуть полоску в контент ПОД секцию Current Selection, как полоска в History. И в History саму полоску (Source/поиск) сделать static, не sticky.
3. [ ] Внутренние отступы: сравнить History и остальные страницы, выровнять (и слева, и справа). Сначала замерить скринами, кто из них выбивается.
4. [ ] Keychain: система постоянно просит доступ, «Always allow» не помогает. Гипотеза: переподпись каждый деплой → cdhash меняется → ACL протухает. Фикс: стабильный designated requirement (identifier + cert anchor) при подписи; проверить `security dump-keychain` ACL, перегранить один раз.
5. [ ] Тост «The original text field is no longer available»: убрать из юзер-видимых сообщений (оставить в логах/debug), заменить на простое «Transcript copied to clipboard.» / «...saved to history.». Файл: TranscriptInsertionService.swift.
6. [ ] Удаление модели: нет подтверждения. Добавить confirmationDialog на Remove/delete модели (и провайдера, если там же).
7. [ ] General: global shortcut перенести сразу после текста «used to start and stop...» следующим предложением/строкой.
8. [ ] General: паттерн из референса (System Settings Switch Control): текст слева, кнопка справа в одном ряду; одиночная кнопка — справа; подписи — где рационально. Основное на General.
9. [ ] History: lazy load/пагинация + поиск по всем записям, чтобы много записей не вешало UI.

Инфра для проверки: QA-хук `TRANSCRIPTOR_QA_SCREEN`/`TRANSCRIPTOR_QA_SNAPSHOT` → PNG на маке; деплой: release.yml → DMG → переподпись «Transcriptor Local Dev 2026» → /Applications. CI перед релизом зелёный.
Статус-файл обновлять по ходу. Прогресс отмечать в этом файле.
