mailbox = require '../lib/mailbox'


mail = new mailbox({
    user: ""
    password: ""
    host: ""
    port: 993
    tls: true
})

mail.getMailboxes (err, mailboxes) ->
    if err
        console.log err
    else
        console.log mailboxes


mail.getMail {}, (err, mail) ->
    if err
        console.log err
    else 
        console.log mail
