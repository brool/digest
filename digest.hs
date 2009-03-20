import System
import System.Locale
import Data.List
import Data.Time.Format
import Data.Time.Clock

import Network.Socket
import Network.BSD
import Network.SMTP.Client

import Text.ParserCombinators.Parsec
import Text.ParserCombinators.Parsec.Rfc2822 (Field(..),NameAddr)

import Python.Interpreter
import Python.Objects

-- return a date string numdays ago
since numdays = 
    do t <- getCurrentTime
       let s = addUTCTime ((- numdays)*24*60*60 :: NominalDiffTime) t 
       return $ formatTime defaultTimeLocale "%d-%b-%Y" s

-- simple SMTP send message
sendMessage from to subject text = 
    do hn <- getHostByName "localhost"
       sendSMTP Nothing "localhost" (SockAddrInet 25 (hostAddress hn)) [m]
       where name_from = NameAddr Nothing from
             name_to   = NameAddr Nothing to 
             m = Message [From [name_from], To [name_to], Subject subject] text

-- connect to an imap server and logs in
imapConnect server user pass = 
    do pyImport "imaplib"
       imap_hostname <- toPyObject server
       imap <- callByName "imaplib.IMAP4_SSL" [imap_hostname] []
       runMethodHs imap "login" [user, pass] noKwParms
       runMethodHs imap "select" noParms [("mailbox", "INBOX")]
       return imap

-- helper function: given a value and a Python expression expressed in terms of "x", return the value
-- example: a <- toPyObject 1;  ap a "x+1" :: IO [Integer]
ap v expr = do result <- pyRun_String expr Py_eval_input [("x", v)]
               fromPyObject result

-- return all message IDs newer than date
messagesSince imap sinceDate = 
    do args <- sequence $ [pyRun_String "None" Py_eval_input [], 
                   toPyObject "SINCE", toPyObject sinceDate]
       search <- getattr imap "search"
       result <- pyObject_Call search args []
       rva <- ap result "x[1]" :: IO [String]
       return $ reverse $ map (\x -> read x :: Integer) $ (words . head) rva

-- fetchMessage
imapFetch imap fields msgid = 
    do fetch <- getattr imap "fetch"
       args <- sequence $ [toPyObject msgid, toPyObject fields]
       msg <- pyObject_Call fetch args []
       ap msg "x[1][0][1]" :: IO [Char]

-- get the list of messages
main = do py_initialize
          [from, to, host, userid, password] <- getArgs
          imap <- imapConnect host userid password
          from_date <- since 1
          new_messages <- messagesSince imap from_date 
          text <- mapM (imapFetch imap "(BODY[HEADER.FIELDS (FROM SUBJECT DATE)])") new_messages
          sendMessage from to ("Digest for " ++ from_date) (concat text)
