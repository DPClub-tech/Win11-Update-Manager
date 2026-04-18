# Windows 11 Update Manager v4.0

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)](https://microsoft.com/powershell)
[![Windows 11](https://img.shields.io/badge/Windows-11-purple)](https://microsoft.com/windows)

Утилита для управления Центром обновлений Windows 11. Позволяет включать, отключать, восстанавливать и проверять обновления через удобное консольное меню.

## 📋 Возможности

| Функция | Описание |
|---------|----------|
| **Enable + Repair (Full)** | Полное включение + восстановление путей служб, удаление блокирующих политик, запуск DISM и SFC |
| **Enable (Fast)** | Быстрое включение через реестр и запуск служб (без проверки системы) |
| **Disable** | Полное отключение обновлений через политики, остановка служб и очистка кэша |
| **Open Windows Update** | Быстрый переход в настройки Центра обновлений |
| **Self-Update** | Автоматическая проверка и установка новой версии скрипта |

## 🚀 Быстрый старт

### Требования
- Windows 11
- PowerShell 5.1 или новее
- Права администратора (скрипт запросит автоматически)

### Установка и запуск

**Способ 1 — через скачивание:**
```powershell
# Скачать скрипт
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DPClub-tech/Win11-Update-Manager/main/Win11_Update_Manager.ps1" -OutFile "$env:USERPROFILE\Desktop\Win11_Update_Manager.ps1"

# Запустить
cd "$env:USERPROFILE\Desktop"
powershell -ExecutionPolicy Bypass -File "Win11_Update_Manager.ps1"
