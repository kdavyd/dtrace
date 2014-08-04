#!/usr/bin/python
import sys
import pprint
from datetime import datetime,date,time

def main():
    print str(sys.argv)
    input = sys.argv[1]
    i=0
    with open(input) as f:
        dl={}
        dt=""
        while True:
            line = f.readline()
            if dt != False:
                prev_dt = dt
                print dt
            dt = is_timestamp(line)
            if dt == False:
                if not (line.split()[0].startswith("------") or line.split()[0].startswith("Dataset")):
                    dp_convert_and_write(line,prev_dt)

def is_timestamp(t):
    try:
        return datetime.strptime(" ".join(t.split()[0:4]),"%Y %b %d %H:%M:%S")
    except ValueError:
        return False

def dp_convert_and_write(t,t_date):
    dp = {}
    t = t.split()
    f = open (t[0].replace("/","_")+".zfsio.csv", "a")
    f.write(datetime.strftime(t_date,'%Y-%m-%d-%T')+','+t[1]+','+t[2]+','+t[3]+','+t[4]+','+t[5]+','+t[6]+'\n')
    f.close()

if __name__ == "__main__":
        main()
