import subprocess
from collections import deque
import re

#with open("results.csv","w") as f:
#    f.write("");

for i in range(2,257,2):
    process = subprocess.Popen(['make','clean', 'compile','simulator','ALLOC_SIZE='+str(i)], stdout=subprocess.PIPE);
    while True:
        output = process.stdout.readline()
        if(output.strip() == b"" and process.poll() is not None):
            break;
        if(output.strip() != b""):
            pass;#print(output.strip());
    rc = process.poll()
    print("Rc:", rc);

    process = subprocess.Popen(['./exe_HW_sim'], stdout=subprocess.PIPE);
    d = deque([""]*2);
    while True:
        output = process.stdout.readline().decode('utf-8');
        if(output.strip() == "" and process.poll() is not None):
            break;
        if(output.strip() != ""):
            d.pop();
            d.appendleft(output.strip());
            print(output.strip());
    nums = (list(map(lambda x: int(re.match(r"^(\d*):", x).group(1)), list(d))));
    diff = nums[0] - nums[1];
    print(i//2, diff);

    results = open("results.csv","a");
    results.write(f"{i//2},{diff}\n");
    results.close();

