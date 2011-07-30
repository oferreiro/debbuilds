#!/usr/bin/python

# dictionaryAttack.py
# Author: Aaron Sinclair
# version 1.2
# PURPOSE: monitors VPS's logs for brute force / dictionary type attacks and adds an IP
# Tables rule to ban offending hosts incoming SSH port 22
# 8 feb 2005: Added a check for lockfile to ensure only one process runs
# at any one time.  Issues are if an instance crashes, the lockfile will be
# left in place and future attempts to run this script will fail. Manual
# removal of the lockfile will be required.
# #
#

import os, re, time, string, sys

class dictionaryAttack:
    def __init__(self):

        #IGNORE LIST; add as many ip addresses as needed.
        #This will ensure that these ip addresses are NOT blocked from accessing your system
        self.ignoreList = ['127.0.01', '1.1.1.1']  # replace 1.1.1.1 with your remote SSH ipaddress

        self.numFailedAttempts = 15                      #numer of failed logins.
        self.fileName = "/var/log/auth.log"

        self.linesToRead = "500"                     #how many lines to read from the log
        self.timeToBan = 2592000                      #how many seconds to ban ip for (30 days)
        self.abuserFile = "/var/lib/abuser.txt"      #where to store ip list
        self.lockfile = "/var/run/dicAttackPrev.lock"
        self.iptables = "/sbin/iptables"            #path to iptables
        self.fileContents = []
        self.abuserFileContents = []
        self.banList = []
        self.unbanList = []
        self.iptablesIPLIST = []

        if os.path.exists(self.lockfile):
                sys.exit("FAILED: An instance of this script is already running")
        else:
                os.popen("touch " + self.lockfile, "r")

        #fileContents = file(self.fileName).read()
        #lines=fileContents.splitlines()
        #logLen = len(lines)
        #start = logLen - self.linesToRead
        #self.fileContents = lines[start:logLen]

        syslogObj = os.popen("tail " + self.fileName + " -n " + self.linesToRead + " | grep -i sshd", "r")
               
        for line in syslogObj:
                self.fileContents.append(line)
           
        if os.path.exists(self.abuserFile):
           self.abuserFileContents = file(self.abuserFile).readlines()

    def identifyHost(self):

        hits = {} 
        for line in self.fileContents:
                if re.search("failed password", line.lower()):
                        ip = re.search("[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}", line)

                        if ip.group() in self.ignoreList:
                                continue

                        if ip.group() in hits:
                                hits[ip.group()] = hits[ip.group()] + 1
                        else:
                                hits[ip.group()] = 1

                        if hits[ip.group()] > self.numFailedAttempts: 
                                if not ip.group() in self.banList:
                                        self.banList.append(ip.group())


    def verifyIPTABLES(self):
        iptablesFileOb = os.popen(self.iptables + " -L -n |grep dpt:22|grep DROP", "r")
        iptables = []
        for line in iptablesFileOb:
                iptables.append(line)

        for line in self.abuserFileContents:
                ip = string.strip(line[14:])
                ret = self.valInSet(ip, iptables)
                self.iptablesIPLIST.append(ip)
                if not ret:
                        print "result: " + str(ret) + " " + ip + " to be added to firewall"
                        self.banList.append(ip)

    def valInSet(self, val, set):
        val = string.strip(val)
        for line in set:
                inSet = string.find(line, val)
                if inSet > 0:
                        return 1

    def checkDuplicates(self):
        for line in self.abuserFileContents:
                count =0
                for ip in self.banList:
                        if re.search(ip, line):
                                del self.banList[count]
                        count = count + 1

    def removeExpired(self):
        count = 0
        for line in self.abuserFileContents:
            tstamp = float(re.sub(":","",line[0:13]))
            if (tstamp + self.timeToBan) < time.time():
                del self.abuserFileContents[count]
                ip = re.search("[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*", line)
                self.unbanList.append(ip.group(0))
            count = count + 1

    def saveAbuseFile(self):
            f=open(self.abuserFile, "w")
            for line in self.abuserFileContents:
                f.write(line)
            for line in self.banList:
                f.write (str(float(time.time())) + ": " + line + "\n")
            f.close()

    def unbanIp(self):
        for ip in self.ignoreList:
                if ip in self.iptablesIPLIST:
                        self.unbanList.append(ip)
        for ip in self.unbanList:
                cmd = self.iptables + " -D INPUT -s " + ip + " -p tcp --destination-port 22 -j DROP"
                print cmd
                os.system(cmd)

                cmd = self.iptables + " -D FORWARD -s " + ip + " -p tcp --destination-port 22 -j DROP"
                print cmd
                os.system(cmd)

    def banIp(self):
        for ip in self.banList:
                cmd = self.iptables + " -I INPUT -s " + ip + " -p tcp --destination-port 22 -j DROP"
                print cmd
                os.system(cmd)

                cmd = self.iptables + " -I FORWARD -s " + ip + " -p tcp --destination-port 22 -j DROP"
                print cmd
                os.system(cmd)

    def cleanup(self):
        os.popen("rm -f " + self.lockfile)


attack = dictionaryAttack()
attack.identifyHost()
attack.checkDuplicates()
attack.removeExpired()
attack.saveAbuseFile()
attack.verifyIPTABLES()
attack.unbanIp()
attack.banIp()
attack.cleanup()