#!/bin/bash

par1=$(snmpget -c public -v 1 $1 $2 | tr -d "\n" | tr -s " " | cut -f 4- -d " " | tr -d " ")
echo $par1 | xxd -r -p


# Команда tr служит для перевода (замены) выбранных символов в другие символы или удаления их.
# Опция -d Используется для удаления из текста символов, перечисленных в наборе \n -- новая строка
# Опция -s Эта опция позволяет заменить повторяющиеся подряд символы из набора на единственный символ из списка " " 
# cut -  для фильтрации текста, Она фильтрует STDIN из другой команды или из файла и отправляет фильтрованный вывод в STDOUT
# -f выбирает только поля, перечисленные в списке. Разделителем по умолчанию служит TAB. Значение по умолчанию может быть # переопределено с помощью опции -d 
# 4- будут выведены все байты, символы или поля, начиная с 4-го.