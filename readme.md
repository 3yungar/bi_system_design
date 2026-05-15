# BI System: Metabase + PostgreSQL + Olist

Учебный BI-проект на базе PostgreSQL, Metabase и открытого датасета Olist Brazilian E-Commerce. Проект поднимается через Docker Compose, загружает нормализованные CSV-данные в PostgreSQL и создает готовые аналитические представления для Metabase.

## Что внутри

- PostgreSQL 16 для хранения данных.
- Metabase для дашбордов и ad hoc аналитики.
- Olist Brazilian E-Commerce dataset: заказы, товары, продавцы, клиенты, платежи, отзывы и доставка.
- SQL-инициализация БД `olist_db`.
- Готовая схема `analytics` с views для быстрых BI-задач.

## Быстрый старт

1. Скачайте CSV-файлы Olist:

    ```bash
    ./scripts/download_olist.sh
    ```

2. Если проект уже запускался раньше, пересоздайте volume PostgreSQL, чтобы init-скрипты отработали заново:

    ```bash
    docker compose down -v
    ```

3. Запустите стенд:

    ```bash
    docker compose up -d
    ```

4. Откройте Metabase:

    - локально: [http://localhost:3000](http://localhost:3000)

5. Создайте первого пользователя Metabase.

6. Добавьте аналитическую БД в Metabase:

    - Database type: `PostgreSQL`
    - Host: `postgres`
    - Port: `5432`
    - Database name: `olist_db`
    - Username: `metabase_user`
    - Password: `metabase_pass`

Для подключения к PostgreSQL с хоста используйте:

```bash
psql -h localhost -p 5433 -U metabase_user -d olist_db
```

## Деплой в Yandex Cloud

Этот сценарий поднимает ту же BI-систему на виртуальной машине Yandex Cloud. Подключение к серверу выполняется обычным SSH из PowerShell, Terminal или любого другого терминала.

### 1. Подготовьте SSH-ключ

Если SSH-ключа еще нет, создайте его на своем компьютере:

```bash
ssh-keygen -t ed25519 -C "yc-bi-system"
```

Публичный ключ нужно вставить при создании виртуальной машины.

PowerShell:

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub
```

macOS или Linux:

```bash
cat ~/.ssh/id_ed25519.pub
```

### 2. Создайте виртуальную машину

В Yandex Cloud откройте `Compute Cloud` -> `Virtual machines` -> `Create virtual machine`.

Рекомендуемые параметры для учебного стенда:

- OS image: `Ubuntu 24.04 LTS` или `Ubuntu 22.04 LTS`.
- vCPU: `2`.
- RAM: `4 GB`.
- Disk: `30 GB SSD` или больше.
- Public IPv4: `Auto`.
- Login: `yc-user` или свой логин.
- SSH key: вставьте публичный ключ из предыдущего шага.

В группе безопасности откройте входящие правила:

- TCP `22` только с вашего IP-адреса для SSH.
- TCP `3000` с вашего IP-адреса или `0.0.0.0/0`, если Metabase должен быть публично доступен.

Порт PostgreSQL `5433` публично открывать не нужно. Для подключения к базе с компьютера используйте SSH-туннель.

### 3. Подключитесь к серверу

После создания VM скопируйте ее публичный IP-адрес.

PowerShell, macOS Terminal или Linux terminal:

```bash
ssh yc-user@<PUBLIC_IP>
```

Если при создании VM указали другой login, замените `yc-user` на него.

### 4. Установите Docker и Git на сервере

Выполните на сервере:

```bash
sudo apt update
sudo apt install -y ca-certificates curl git
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

На сервере команды Docker можно выполнять через `sudo`. Если хотите запускать Docker без `sudo`, добавьте пользователя в группу `docker`, выйдите с сервера и подключитесь заново:

```bash
sudo usermod -aG docker $USER
exit
ssh yc-user@<PUBLIC_IP>
```

Проверьте установку:

```bash
sudo docker version
sudo docker compose version
```

### 5. Скачайте проект и данные

На сервере:

```bash
git clone https://github.com/3yungar/bi_system_design.git
cd bi_system_design
./scripts/download_olist.sh
```

CSV-файлы скачиваются в `data/olist/` и не коммитятся в git.

### 6. Запустите BI-систему

```bash
sudo docker compose up -d
sudo docker compose ps
```

Откройте Metabase:

```text
http://<PUBLIC_IP>:3000
```

При первичной настройке Metabase добавьте аналитическую базу:

- Database type: `PostgreSQL`
- Host: `postgres`
- Port: `5432`
- Database name: `olist_db`
- Username: `metabase_user`
- Password: `metabase_pass`

### 7. Подключитесь к PostgreSQL через SSH-туннель

Если нужно работать с базой с локального компьютера, откройте отдельный PowerShell или Terminal:

```bash
ssh -L 5433:localhost:5433 yc-user@<PUBLIC_IP>
```

Пока это окно открыто, подключайтесь к PostgreSQL локально:

```bash
psql -h localhost -p 5433 -U metabase_user -d olist_db
```

### 8. Обновление и перезапуск

На сервере:

```bash
cd bi_system_design
git pull
sudo docker compose pull
sudo docker compose up -d
```

Если изменились SQL-скрипты или CSV и нужно пересоздать базу:

```bash
sudo docker compose down -v
sudo docker compose up -d
```

## Структура проекта

```text
bi_system_design/
├── docker-compose.yml
├── data/olist/                 # Скачанные CSV, не коммитятся
├── initdb/
│   ├── 01_create_olist_schema.sql
│   ├── 02_load_olist_data.sql
│   └── 03_create_analytics_views.sql
├── scripts/
│   └── download_olist.sh
├── images/
├── .gitignore
└── readme.md
```

## Таблицы

База `olist_db` содержит исходные таблицы:

- `customers`
- `geolocation`
- `sellers`
- `products`
- `product_category_name_translation`
- `orders`
- `order_items`
- `order_payments`
- `order_reviews`

## Аналитические views

Схема `analytics` создается автоматически:

- `analytics.order_items_enriched` — строки заказов с товарами, категориями, продавцами и клиентами.
- `analytics.orders_enriched` — один ряд на заказ с выручкой, оплатами, отзывами и доставкой.
- `analytics.daily_sales` — дневные продажи, оплаты, отзывы и доставка.
- `analytics.product_category_metrics` — метрики по категориям товаров.
- `analytics.seller_metrics` — метрики по продавцам.
- `analytics.delivery_performance` — качество доставки по городам и штатам клиентов.

## Пересоздать базу

Если изменились SQL-скрипты или CSV, пересоздайте volume PostgreSQL:

```bash
docker compose down -v
docker compose up -d
```

Если нужно заново скачать CSV:

```bash
rm -f data/olist/*.csv
./scripts/download_olist.sh
```

## Типовые учебные задачи

- Построить воронку заказов по статусам.
- Посчитать GMV, средний чек и динамику продаж по дням.
- Найти категории с лучшей и худшей оценкой.
- Сравнить продавцов по выручке и срокам доставки.
- Оценить долю поздних доставок по регионам.
- Найти связь между сроком доставки и оценкой клиента.
- Сравнить способы оплаты и количество рассрочек.

## Безопасность

Пароли в `docker-compose.yml` учебные. Перед публикацией публичного стенда замените их через `.env`, ограничьте доступ к портам и поставьте HTTPS-прокси перед Metabase.

## Источник данных

CSV скачиваются из репозитория [mara/mara-olist-ecommerce-data](https://github.com/mara/mara-olist-ecommerce-data), закрепленного на commit `663660edff1b4cd711a172027081915771628b9f`.
