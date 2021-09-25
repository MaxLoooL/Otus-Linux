#!/bin/bash

#Переменные
#Полный путь до скрипта
path_to_scpript='/path/to/script'
#Запись в кроне
cron_string=$(crontab -l | grep $path_to_scpript ; echo $?)
#Путь до директории с логами. Нужно указать свой путь до директории, в которой будут создаваться новые файлы с сообщениями
path_to_log_dir='/path/to/dir'
#Первая временная метка из лог файла
first_timestamp=$(cat access.log | awk '{print $4}' | cut -c2- | head -n 1 | tr "/" ":")
#Время сброки сообщений
now_date=$(date | awk '{ print $3 "/",$2 "/", $6 ":", $4}' | sed 's/ //g' | tr "/" ":")
#Создание нового лог файла с временной меткой
touch $path_to_log_dir/$now_date.log
#Последний созданный файл в директории с сообщениями
last_created_file=$(ls -t $path_to_log_dir | head -1 ) 
#Полный путь до последнего созданного сообщения
full_path_to_new_file="$path_to_log_dir/$last_created_file"
#Все IP адреса из лог файла
all_ip_addresses=$(cat access.log| awk '{print $1}')
#Все адреса, к которым были обращения в лог файле
all_addresses=$(cat access.log | awk '{print $11}' | sed 's/"-"//g' | sed 's/uct=//g' | sed '/^[[:space:]]*$/d')
#Все ошибки из лог файла с указанием IP адреса, с которого был сделан запрос
all_errors=$(cat access.log | grep error | awk '{ print "From address " $1, "at time ", $4 " error code - " $7}')
#Все коды запросов из лог файла
list_with_all_responce_code=$(cat access.log | awk '{print $9}' | sed 's/"-"//g' |sed '/^[[:space:]]*$/d')


#X IP адресов (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта
collected_ip_addresses() {
while IFS= read -r line
do
	sort | uniq -c | sort -rn | head -n 10
done < <(printf '%s\n' "$all_ip_addresses") 
}

#Y запрашиваемых адресов (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта
collected_addresses() {
while IFS= read -r line
do
	sort | uniq -c | sort -rn | head -n 10
done < <(printf '%s\n' "$all_addresses") 
}

#все ошибки c момента последнего запуска
collected_errors() {
while IFS= read -r line
do
	echo $line
done < <(printf '%s\n' "$all_errors") 
}

#список всех кодов возврата с указанием их кол-ва с момента последнего запуска
collected_responce_code() {
while IFS= read -r line
do
	sort | uniq -c | sort -rn 
done < <(printf '%s\n' "$list_with_all_responce_code") 
}

#Создание сообщения
create_message(){
	echo "Временной диапазон c" $first_timestamp "по" $now_date  >> $full_path_to_new_file
	echo "------------------------------------------------------" >> $full_path_to_new_file
	echo $'\n'Таблица с топ 10 IP аресами и количеством запросов с этих адресов >> $full_path_to_new_file
	collected_ip_addresses >> $full_path_to_new_file
	echo $'\n'Таблица с топ 10 запрашиваемыми URL и их количеством >> $full_path_to_new_file
	collected_addresses >> $full_path_to_new_file
	echo $'\n'Все ошибки из лог файла с указанием IP адреса, с которого был сделан запрос, времени запроса и ошибкой >> $full_path_to_new_file
	collected_errors >> $full_path_to_new_file
	echo $'\n'Список всех кодов возврата с указанием их количества в лог файле >> $full_path_to_new_file
	collected_responce_code >> $full_path_to_new_file  
}
create_message

#Отправка письма. Вместо your_user необходимо указать пользователя, которому будут доставлятся сообщения
cat $full_path_to_new_file | mail -s "NGINX Log Info" your_user@localhost 

#Создание записи в кроне с защитой от мультизапуска. Если запись уже существует, то создаваться повторно не будет. Так же происходит установка lockrun, если ее нет на хосте
install_lockrun(){
	wget unixwiz.net/tools/lockrun.c && sleep 5 && gcc lockrun.c -o lockrun && mv lockrun /usr/local/bin/
}
create_cron(){
	crontab -l | { cat; echo "@hourly /usr/local/bin/lockrun --maxtime=9 --lockfile=$path_to_scpript"; } | crontab - && install_lockrun
}

if [[ "$cron_string" =~ [1] ]]; then
	create_cron
else
exit 0
fi




