# Инструкция по запуску

## Требования

Нужен установленный Flutter SDK с поддержкой Windows и Android.

Проверка:

```powershell
flutter doctor
```

## Задание 1

```powershell
cd C:\Users\epitaph\VYZ\kursov\zadanie_1_files
flutter run -d windows
```

Проверка:

1. нажать `Добавить`;
2. заполнить блюдо;
3. изменить запись через кнопку с карандашом;
4. удалить запись через кнопку корзины;
5. сохранить JSON;
6. загрузить этот JSON обратно.

## Задание 2

```powershell
cd C:\Users\epitaph\VYZ\kursov\zadanie_2_class_diagram
flutter run -d windows
```

Пример `.h` файла для проверки:

```cpp
class Person {};
class Student : public Person {};
class Teacher : public Person {};
class GroupLeader : public Student {};
```

После выбора файла приложение должно показать диаграмму наследования.

## Задание 3

Первый экземпляр:

```powershell
cd C:\Users\epitaph\VYZ\kursov\zadanie_3_udp_chat
flutter run -d windows -- --db=C:\Temp\chat1.db --local-port=5001 --remote-host=127.0.0.1 --remote-port=5002
```

Второй экземпляр:

```powershell
cd C:\Users\epitaph\VYZ\kursov\zadanie_3_udp_chat
flutter run -d windows -- --db=C:\Temp\chat2.db --local-port=5002 --remote-host=127.0.0.1 --remote-port=5001
```

После запуска в обоих окнах нужно нажать `Запустить`, затем отправлять сообщения.

Если приложение уже собрано под Windows, можно запускать exe-файл напрямую:

```powershell
.\build\windows\x64\runner\Debug\zadanie_3_udp_chat.exe --db=C:\Temp\chat1.db --local-port=5001 --remote-host=127.0.0.1 --remote-port=5002
```

На Android аргументы командной строки обычно не используются, поэтому адрес, порты и путь к БД можно заполнить прямо в интерфейсе. Если путь к БД оставить пустым, приложение создаст файл `udp_chat_log.db` в папке документов приложения.

## Команды проверки

Для каждого проекта:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows
flutter build apk --debug
```
