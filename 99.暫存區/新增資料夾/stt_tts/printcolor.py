from colorama import Fore, Style
# print(Fore.BLUE + "[程式輸出] 這是 print 的訊息" + Style.RESET_ALL)

def color(text, color = "BLUE"):
    colorMap = {
        "RED": Fore.RED,
        "GREEN": Fore.GREEN,
        "BLUE": Fore.BLUE,
        "YELLOW": Fore.YELLOW,
        "CYAN": Fore.CYAN,
        "PURPLE": Fore.MAGENTA,
        "WHITE": Fore.WHITE,
        "BLACK": Fore.BLACK,
        "LIGHTRED": Fore.LIGHTRED_EX,
        "LIGHTGREEN": Fore.LIGHTGREEN_EX,
        "LIGHTBLUE": Fore.LIGHTBLUE_EX,
        "LIGHTYELLOW": Fore.LIGHTYELLOW_EX,
        "LIGHTCYAN": Fore.LIGHTCYAN_EX,
        "LIGHTPURPLE": Fore.LIGHTMAGENTA_EX,
        "LIGHTWHITE": Fore.LIGHTWHITE_EX,
        "LIGHTBLACK": Fore.LIGHTBLACK_EX
    }
    # color = input("red, green, blue, yellow, cyan, magenta, white?")
    colorCode = colorMap.get(color.upper())
    return (colorCode + str(text) + Style.RESET_ALL)

# print(color("test", "lightpurple"))
# print(color(f"模型下載路徑:{checkpoint_dir}"))
# input(color("plz input text:"))