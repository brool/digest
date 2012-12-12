#!/usr/bin/python
# create a digest of e-mail in the past 24 hours

import cStringIO as StringIO
import imaplib
import smtplib
import datetime
import getopt
import sys
import email.MIMEText

args = []

try:
    opt, args = getopt.getopt(sys.argv[1:], "", ["days="])
except getopt.GetoptError:
    pass

if len(args) < 5:
    print "usage: digest.py [--days=nn] from-mail to-mail imap-host imap-userid imap-password"
    sys.exit(0)

opt = dict(opt)
mail_from = args[0]
mail_to = args[1]
imap_host = args[2]
imap_userid = args[3]
imap_password = args[4]
imap_days = int(opt.get("--days", 1))

if (imap_password[0] == '@'):
    imap_password = file(imap_password[1:], 'rt').read().strip()

since = datetime.datetime.today() - datetime.timedelta(days=imap_days)
since = since.strftime("%d-%b-%Y")

imap = imaplib.IMAP4_SSL(imap_host)
imap.login(imap_userid, imap_password)
imap.select(mailbox="INBOX")
typ, dat = imap.search(None, 'SINCE', since)

buf = StringIO.StringIO()
msgs = map(int, dat[0].split())

if msgs:
    msgs.reverse()

    for msg in msgs:
        fields = imap.fetch(msg, '(BODY[HEADER.FIELDS (FROM SUBJECT DATE)])')
        buf.write( fields[1][0][1] )

    msg = email.MIMEText.MIMEText(buf.getvalue())
    msg['Subject'] = "Digest for %s" % since
    msg['From'] = mail_from
    msg['Reply-to'] = mail_from
    msg['To'] = mail_to

    s = smtplib.SMTP()
    s.connect("localhost")
    s.sendmail(mail_from, mail_to, msg.as_string())
    s.close()
