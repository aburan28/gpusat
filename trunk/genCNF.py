import os, sys, random, re;

if(len(sys.argv) != 5):
    print "\npython genCNF.py <numLiterals> <numClauses> <0 = sat, 1 = unknown> <filename>\n";
    sys.exit(0);

numLiterals = int(sys.argv[1]);
numClauses = int(sys.argv[2]);
unknown = int(sys.argv[3]);
filename = sys.argv[4];

FILE = open(filename, "w");

finalSolution = [];

finalSolution.append(0);

# Seed is randomized with each run!
for i in range(0, numLiterals):
    finalSolution.append(random.randrange(-1,2,2)); # 1 is positive, -1 is negative
    
print "Precalculated satisfiable solution: ";
print finalSolution;

FILE.write("p cnf " + str(numLiterals) + " " + str(numClauses) + "\n");
for i in range(0, numClauses):
    numVars = 3; #random.randint(2,3);  # Only generate with 2 or 3 vars per clause
    satisfied = 0;
    inverse = 1;   # -1 if invert, 1 if non-invert

    takenValues = [];
    for j in range(0, numLiterals+1):
        takenValues.append(0);

    for j in range(0, numVars):
        isSat = int(random.randint(0,1));

        literal = random.randint(1, numLiterals);
        while(takenValues[literal] != 0):
            literal = random.randint(1, numLiterals);
        takenValues[literal] = 1;

        if((j == (numVars - 1)) and (satisfied == 0)  and (unknown == 0)):
            inverse = 1;
            satisfied = 1;
        else:
            if(isSat):
                inverse = 1;
                satisfied = 1;
            else:
                inverse = -1;
        
        #if((inverse*finalSolution[literal]) == 1):
        if((inverse*finalSolution[literal]) == 1):
            FILE.write(str(literal));
        else:
            FILE.write("-" + str(literal));  

        FILE.write(" ");

    FILE.write("0\n");

FILE.close();

# Check results!!!
print "Checking generated SAT equation...\n";
FILE = open(filename, "r");

sat = re.compile("(\S+)\s+(\S+)\s+(\S+)\s+(\S+)");

header = 0;
for line in FILE:
    if(header == 0):
        #print "Header: " + line;
        header = 1;
    else:    
        #print line;
        m = sat.match(line);
        if m:
            satisfied = 0;
            for i in range(1, 4):  # 1, 2, 3
                if(int(m.group(i)) < 0):
                    if(finalSolution[int(m.group(i))*-1] == -1):
                        #print "SAT!";
                        satisfied = 1;
                    #else:
                        #print "UNSAT";
                else:
                    if(finalSolution[int(m.group(i))] == 1):
                        #print "SAT!";
                        satisfied = 1;
                    #else:
                        #print "UNSAT";
                    
            if(satisfied == 0):
                print "NOOOOOOOOOOOOOO!!!!!!!! FAILS PRECALCULATED SOLUTION!";
                print "The CNF file is still generated though!";
                sys.exit();
        else:
            print "WTF: " + line;
            
print "Done!";
