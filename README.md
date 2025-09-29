# 🕹️ Mini Roguelike на Godot

![Godot Engine](https://img.shields.io/badge/Godot-4.x-blue?logo=godot-engine&logoColor=white)
![Language](https://img.shields.io/badge/Language-GDScript-orange)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-Completed-brightgreen)

Простая **2D-игра** на **Godot Engine**, где игрок собирает монеты на случайно сгенерированной карте, избегая врагов.  
Проект выполнен как тестовое задание.

---

## 🎮 Геймплей

<p align="center">
  <img src="docs/screenshots/gameplay.gif" alt="Gameplay" width="600"/>
</p>

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

---

## 🖥️ Скриншоты
<img width="1153" height="683" alt="image" src="https://github.com/user-attachments/assets/70c87ea4-ae8a-458b-938f-638a6e975e1d" />
<img width="1147" height="684" alt="image" src="https://github.com/user-attachments/assets/0ec33676-dbb5-4c7b-b81c-1488193fd674" />
<img width="1156" height="692" alt="image" src="https://github.com/user-attachments/assets/83892a7e-3a60-44b2-adc1-2704d84dbd6c" />



