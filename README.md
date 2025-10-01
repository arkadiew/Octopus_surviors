# 🕹️ Mini Roguelike на Godot

![Godot Engine](https://img.shields.io/badge/Godot-4.x-blue?logo=godot-engine&logoColor=white)
![Language](https://img.shields.io/badge/Language-GDScript-orange)
![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Status](https://img.shields.io/badge/Status-Completed-brightgreen)

Простая **2D-игра** на **Godot Engine**, где игрок собирает монеты на случайно сгенерированной карте, избегая врагов.  
Проект выполнен как тестовое задание.

---

## 🎮 Геймплей


- 🔹 **Процедурная генерация карты** (шум Перлина).  
- 🔹 **Игрок**: движение, рывок (**Dash**), стрельба, здоровье.  
- 🔹 **Враги**: патрулирование и погоня через `NavigationAgent2D`.  
- 🔹 **Монеты**: случайный спавн, победа при сборе всех.  
- 🔹 **Сохранения**: позиция игрока, враги, монеты, счёт.  
- 🔹 **UI**: HP bar, счётчик монет, меню, окно победы/поражения.  

---

## ⚙️ Конфигурация

Все настройки находятся в [`config/game_config.cfg`](res://config/game_config.cfg):

- **Игрок**: скорость, здоровье, параметры рывка и стрельбы.  
- **Враги**: скорость, количество, частота спавна.  
- **Монеты**: количество, минимальная дистанция между ними, условия победы.  
- **Карта**: размер, seed генерации, плотность зданий.  

Вес спавна зданий задаётся в [`config/building_weights.cfg`](res://config/building_weights.cfg).

---

## 🚀 Запуск
1. Установи [Godot 4.x](https://godotengine.org/download).  
2. Клонируй репозиторий:
   ```bash
   git clone https://github.com/arkadiew/Octopus_surviors.git
3. Открой проект в Godot.
4. Запусти сцену.
   
---

## 📂 Структура проекта

```text
project/
├── player/            # Игрок (анимации, скрипт Player.gd)
├── enemy/             # Враги с AI
├── coin/              # Монеты
├── assets/            # Графика и звуки (Ninja Adventure Pack)
├── config/            # Настройки игры
├── scripts/           # SaveManager и утилиты
└── main.tscn          # Основная сцена
