---
title: Установка блога Hexo с помощью Docker
date: 2016-06-16 04:46:25
categories:
  - tutorial
tags:
  - Hexo
  - Docker
  - Nginx
  - Системное Администрирование
---

[{% asset_img hexo-logo.svg %}][hexo-url]

Зачастую у многих программистов и гиков возникает желание завести свой блог. Но поднимать таких тяжеловесов как **Wordpress** или **Octopress** нет ни желания (как морального, так и желания тратить лишнии ресурсы своего сервера), ни времени на их настройку и содержание.

Я не случайно выделил программистов и гиков, так как [Hexo][hexo-url] (в своем базовом паке) не имеет ни админки, ни каких-либо привычных вещей для mouse-user'а. Весь движок это по-сути сборщик, перемалывающий **Stylus**'ы, **EJS**'ы, **CoffeeScript**'ы, и конечно-же **Markdown**'ы и собирающий из них статический сайт.

Т.е. вы можете писать в своем блоге, не закрывая **Emacs**. 

<!-- more -->

**Это дает нам ряд преимуществ:**
* сайт статический, а следовательно такие проблемы как БД, рендер страниц, нагрузка на CPU - просто исчезают. Это html страницы, которые занимают лишь место на жестком диске, не нагружая при этом систему.
* так как на выходе мы получаем статические файлы, ни кто нам не запрещает их закинуть, к примеру, на **"Amazon S3"**.

**Из минусов же:**
* нет возможность ([без плагинов][hexo-admin-url]) редактировать посты не через текстовые фалы, следовательно если у вас несколько авторов, вам придется прикручивать [админку][hexo-admin-url], или же давать доступ к SSH (Bucket'у) всем авторам.
* так как у нас нет DB, ни о каких счетчиках, опросниках и комментариях (**Disqus** не в счет) речи быть не может. Естественно, если вы сделаете себе отдельный REST API сервис, или напишете плагин для **Sqlite** эта проблема отпадет (благо, **Hexo** это позволяет более чем. Вообще расширяемость данного фреймворка это отдельная тема, но сейчас опустим это).

Если вас, не смущают эти ~~надуманные~~ минусы, мы можем приступить к установке.

--------------------------------------------------------------------------------

## Docker

Первым делом вам естественно понадобится **Docker**.
*(А на что вы расчитывали, он же указан в заголовке? Если у вы еще не используете это конейнерное чудо, я настоятельно рекомендую исправить этот момент прямо сейчас)*.

Создадим папку под блога:

```bash
sudo mkdir -p /apps/blog
```

А затем, непосредственно, запустим сам контейнер

**Через обычную коммандную строку:**

```bash
sudo docker run \
  --name blog \
  -p 8080:4000
  -v /apps/blog:/app
  -d \
  superpaintman/hexo
```

Кратко, что мы тут сделали, если вы незнакомы с Docker:

1) `--name blog`  - присвоили имя нашему контейнеру
2) `-p 8080:4000` - открыли наружу **8080** порт и сопоставили его с портом **4000** из контейнера (по умолчанию Hexo сервер запускается именно на этом порте)
3) `-v /apps/blog:/app` - прилинковали нашу директорию **/apps/blog** к директории из контейнера
4) `-d` - демонизировали контейнер
5) `superpaintman/hexo` - указали откуда взять контейнер, в нашем случае, это - [Docker HUB: superpaintman/hexo][hexo-docker-url]

Теперь если вы откроете в браузере:

> [//youresite.com:8080](//youresite.com:8080)

вы попадете на свой свеженький блог. По сути дела, на этом вы можете уже отдаться графомании, но давайте сделаем все по-уму


**Через Docker Compose**

Как и в случае с самим **Docker**'ом, я не буду останавливаться на этом, лишь буду надеяться, что вы сможете самостоятельно его установить.

Итак, `docker-compose.yml`:

```yaml
version: "2"
services:
  # nginx
  nginx:
    image: nginx:1.9.14

    container_name: nginx

    restart: always
    links:
      - blog

    volumes:
      - /etc/nginx:/etc/nginx

    ports:
      - "80:80"

  # blog
  blog:
    image: superpaintman/hexo

    container_name: blog

    restart: always

    # ports:
    #   - "4000:4000"
    volumes:
      - /apps/blog:/app
```

тут все, то-же самое, что и в случае с CLI вариантом, единственное отличие, что через Compose наша конфигурация стала более наглядной, а так-же мы можем конфигурировать сразу-же всю экосистему, а не по-одному контейнеру.

Единственное отличие, мы не выносим порт **4000** наружу.

--------------------------------------------------------------------------------

## Nginx

Вы уже наверняка заметили **Nginx**.

Он будет служить нам кеширующим сервером, а так-же это задел на **SSL** сертификат. Естественно, если на этой машине у вас бегает не только **Hexo**, вопрос о необходимости прокси-сервера у вас не должен стоять.

**Конфиг для Nginx:**

`001_youresite.com` **->** `/ect/nginx/sites-available/`

```nginx
###
# youresite.com
###
upstream youresite_com {
  # При линковке, Docker прокидывает локальную сеть в конейнер. В нашем случае это `blog`
  server blog:4000;
}

server {
  listen          80;
  server_name     youresite.com;

  access_log      /var/log/nginx/acc.youresite.com.log;
  error_log       /var/log/nginx/err.youresite.com.log;

  # Static
  location ~ ^/(css|js)/ {
    # Trust Proxy
    include /etc/nginx/snippets/trust_proxy.conf;

    expires 1d;

    proxy_pass http://youresite_com;
  }

  location / {
    # Trust Proxy
    include /etc/nginx/snippets/trust_proxy.conf;

    proxy_pass http://youresite_com;
  }
}
```

**Trust Proxy**:

`trust_proxy.conf` **->** `/ect/nginx/snippets/`

*Так как в контейнере отдачей статики и самих постов занимается Hexo, не плохо было-бы показать ему реальные адреса пользователей. В данном случае это абсолютно бесполезно, но это хороший задел на будущее*

```nginx
proxy_set_header    Host $host;
proxy_set_header    X-Real-IP $remote_addr;
proxy_set_header    X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header    X-Forwarded-Proto $scheme;

proxy_redirect      off;
```

--------------------------------------------------------------------------------

## Расширения

**Hexo** - весьма гибкая платформа, так, что сразу-же установим пару приятных ништяков:

```bash
sudo docker exec blog npm install --save \
  hexo-uglify \
  hexo-autoprefixer \
  hexo-clean-css \
  hexo-autotag
```

1) `hexo-uglify` - так-как вся статика генерируется при запуске сервера, мы можем добавить минификатор **JavaScript**
2) `hexo-clean-css` - минификатор **CSS**
3) `hexo-autoprefixer` - автоматическая вставка вендорных префиксов **CSS**
4) `hexo-autotag` - а так-же тег `autotag`, который может проверять есть ли на сайте записи с данным тегом, и автоматически подставляет линки на них

После установки расширений, перезапустим контейнер, что-бы **Hexo** их подгрузил:

```bash
sudo docker restart blog
```

--------------------------------------------------------------------------------

## Конфигурация

Последний этап, который отделяет нас от написания нешей первой статьи - конфигурация

```bash
cd /apps/blog/
vim ./_config.yml
```

Тут нам достаточно указать:

```yaml
# Имя блога
title: My amazing blog
# SEO описание
description:
# Ваше имя
author: John Doe

# Ссылку на ваш сайт
url: http://yoursite.com
```

--------------------------------------------------------------------------------

## Блоггерство

Теперь вы готовы написать свой первый пост. Волнует, не правда ли? Конечно ж нет, это обычный пост.

```bash
cd /apps/blog/source/_posts/
```

Можете удалить автоматически сгенерированный пост.

```bash
vim ./first_post.md
```

> заметьте, расширение файла обязательно должно быть `.md`

```markdown
---
title: Мой первый пост
tags:
  - Hexo
  - Hello world
---

Я только, что установил **Hexo**!

```

Остается только сохранить этот файл, и демон внутри контейнера автоматически отрендарит его, и вы сможете прочесть свой шедевр на:

> [//youresite.com/first_post](//youresite.com/first_post)

--------------------------------------------------------------------------------

## Документация

Больше о настройке и кастомизации **Hexo** вы сможете найти в его [официальной документации][hexo-docs-url].

Удачного блоггерства и утешения своего эго :)

[hexo-url]: //hexo.io/
[hexo-docs-url]: //hexo.io/docs/
[hexo-admin-url]: //github.com/jaredly/hexo-admin
[hexo-docker-url]: //hub.docker.com/r/superpaintman/hexo/
