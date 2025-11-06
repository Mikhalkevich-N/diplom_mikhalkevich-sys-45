
#  Дипломная работа по профессии «Системный администратор»
#### Выполнила: Михалкевич Надежда Владимировна
#### Группа: SYS-45

## Задача
Ключевая задача — разработать отказоустойчивую инфраструктуру для сайта, включающую мониторинг, сбор логов и резервное копирование основных данных. Инфраструктура должна размещаться в [Yandex Cloud](https://cloud.yandex.com/) и отвечать минимальным стандартам безопасности: запрещается выкладывать токен от облака в git. Используйте [инструкцию](https://cloud.yandex.ru/docs/tutorials/infrastructure-management/terraform-quickstart#get-credentials).

### Инфраструктура
Для развёртки инфраструктуры используйте Terraform и Ansible.  

Не используйте для ansible inventory ip-адреса! Вместо этого используйте fqdn имена виртуальных машин в зоне ".ru-central1.internal". Пример: example.ru-central1.internal  - для этого достаточно при создании ВМ указать name=example, hostname=examle !! 

### Сайт
Создайте две ВМ в разных зонах, установите на них сервер nginx, если его там нет. ОС и содержимое ВМ должно быть идентичным, это будут наши веб-сервера.

Используйте набор статичных файлов для сайта. Можно переиспользовать сайт из домашнего задания.

Виртуальные машины не должны обладать внешним Ip-адресом, те находится во внутренней сети. Доступ к ВМ по ssh через бастион-сервер. Доступ к web-порту ВМ через балансировщик yandex cloud.

Настройка балансировщика:

1. Создайте [Target Group](https://cloud.yandex.com/docs/application-load-balancer/concepts/target-group), включите в неё две созданных ВМ.

2. Создайте [Backend Group](https://cloud.yandex.com/docs/application-load-balancer/concepts/backend-group), настройте backends на target group, ранее созданную. Настройте healthcheck на корень (/) и порт 80, протокол HTTP.

3. Создайте [HTTP router](https://cloud.yandex.com/docs/application-load-balancer/concepts/http-router). Путь укажите — /, backend group — созданную ранее.

4. Создайте [Application load balancer](https://cloud.yandex.com/en/docs/application-load-balancer/) для распределения трафика на веб-сервера, созданные ранее. Укажите HTTP router, созданный ранее, задайте listener тип auto, порт 80.

Протестируйте сайт
`curl -v <публичный IP балансера>:80` 

### Мониторинг
Создайте ВМ, разверните на ней Zabbix. На каждую ВМ установите Zabbix Agent, настройте агенты на отправление метрик в Zabbix. 

Настройте дешборды с отображением метрик, минимальный набор — по принципу USE (Utilization, Saturation, Errors) для CPU, RAM, диски, сеть, http запросов к веб-серверам. Добавьте необходимые tresholds на соответствующие графики.

### Логи
Cоздайте ВМ, разверните на ней Elasticsearch. Установите filebeat в ВМ к веб-серверам, настройте на отправку access.log, error.log nginx в Elasticsearch.

Создайте ВМ, разверните на ней Kibana, сконфигурируйте соединение с Elasticsearch.

### Сеть
Разверните один VPC. Сервера web, Elasticsearch поместите в приватные подсети. Сервера Zabbix, Kibana, application load balancer определите в публичную подсеть.

Настройте [Security Groups](https://cloud.yandex.com/docs/vpc/concepts/security-groups) соответствующих сервисов на входящий трафик только к нужным портам.

Настройте ВМ с публичным адресом, в которой будет открыт только один порт — ssh.  Эта вм будет реализовывать концепцию  [bastion host]( https://cloud.yandex.ru/docs/tutorials/routing/bastion) . Синоним "bastion host" - "Jump host". Подключение  ansible к серверам web и Elasticsearch через данный bastion host можно сделать с помощью  [ProxyCommand](https://docs.ansible.com/ansible/latest/network/user_guide/network_debug_troubleshooting.html#network-delegate-to-vs-proxycommand) . Допускается установка и запуск ansible непосредственно на bastion host.(Этот вариант легче в настройке)

Исходящий доступ в интернет для ВМ внутреннего контура через [NAT-шлюз](https://yandex.cloud/ru/docs/vpc/operations/create-nat-gateway).

### Резервное копирование
Создайте snapshot дисков всех ВМ. Ограничьте время жизни snaphot в неделю. Сами snaphot настройте на ежедневное копирование.


## Выполнение работы

### 1.1 Создание сервисного аккаунта, ключа и переменных.

Создаю сервисный аккаунт в облаке. Выдаю права editor.
Выпускаю авторизованный ключ для этого аккаунта и скачиваю его в домашний каталог по пути ~/.authtorized_key.json.

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-7.png)

Вписываю в переменные cloud_id и folder_id в variables.tf

### 1.2 Установка и подготовка Terraform.

Скачиваю и распаковываю последнюю стабильную версию на 2.10.2025г. сайта: https://hashicorp-releases.yandexcloud.net/terraform/

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image.png)

Создаю файл `.terraformrc` и добавляю блок с источником, из которого будет устанавливаться провайдер.

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-2.png)

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-1.png)

Для файла с метаданными, `meta.yaml`, необходим публичный SSH-ключ для доступа к ВМ. Для Yandex Cloud рекомендуется использовать алгоритм Ed25519: сгенерированные по нему ключи — самые безопасные. 

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-4.png)

Создаю файл `meta.yaml` с данными пользователя на создаваемые ВМ.

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-10.png)

Создаю main.tf` c блоком провайдера и блоки для создания инфраструктуры в Yandex Cloud:
Nginx-web-1, Nginx-web-2, Target group, Backend group,  HTTP router, Application load balancer, Zabbix, Elasticsearch, Kibana, Network, Subnet. Gateway. Route table, Security_groups, Bastion, Snapshot_schedule.

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-11.png)

[ main.tf ](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/terraform/main.tf)

Создаю файл outputs.tf для вывода информации в консоль по созданию ВМ.

[outputs.tf ] (https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/terraform/outputs.tf)

Инициализирую провайдера.

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-3.png)

Terraform готов к использованию.

### 1.3 Установка и подготовка Ansible.

Устанавливаю Ansible и проверяю версию.

```
apt install ansible
ansible --version
```
![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-8.png)

Создаю файл ansible.cfg :

ansible.cfg. Раскоментировала и заполнила следующие строки:
```
inventory      = ./hosts.ini
host_key_checking = false
remote_user = nmu
private_key_file = /nmu/.ssh/id_ed25519
become=True
```
Создаю ansible-файлы для Zabbix, Elasticsearch, Kibana, Nginx, filebeat:

### 2. Создание инфраструктуры в Yandex Cloud

Запуск terraform

```
terraform apply

```

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-21.png)


Вывод информации в консоль по созданию ВМ.

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-39.png)

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-45.png)

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-46.png)

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-52.png)

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-47.png)

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-49.png)

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-48.png)

### 3. Проверка и настройка ресурсов

Создаю файл hosts и добавляю в него начальные данные:

```
sudo nano ~/hosts.ini
```
![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-40.png)

Nginx на 2 ВМ. Замена стандартного файла на index.nginx.html
[index.nginx.html](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/ansible/index.nginx.html)

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-13.png)


Elasticsearch

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-14.png)

Kibana

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-15.png)

Zabbix

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-16.png)

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-17.png)

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-18.png)

 Filebeat

 ![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-19.png)

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-20.png)

Проверка и настройка ресурсов.

 Сайт. Серверы Nginx

 ```
curl -v <публичный IP балансера>:80

curl -v 158.160.139.105:80
```
![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-50.png)

```
http://158.160.139.105

```
![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-51.png)

Мониторинг. Zabbix.

```
http://158.160.128.50/zabbix

```
![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-43.png)

Bводим пароль из playbook-zabbix.yaml

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-44.png)

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-27.png)

![png](imahttps://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-28.png)

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-)29.png)

```
login: Admin
password: zabbix
```
![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-30.png)

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-31.png)

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-32.png)

Логи. Elasticsearch, Kibana, Filebeat.

Запуск Kibana:
```
http://84.201.149.73:5601

```

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-33.png)

Создаю Index patern:

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-34.png)

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-35.png)

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-36.png)

Логи отправляются:

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-37.png)

![png](https://github.com/Mikhalkevich-N/diplom_mikhalkevich-sys-45/blob/main/img/image-38.png)



