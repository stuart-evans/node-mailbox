iMap = require 'imap'
_ = require 'underscore'


module.exports = class mailbox

    constructor: (@opts) ->

    getMailboxes: (cb) =>
        mailboxes = {}
        imap = new iMap @opts
        imap.connect()

        imap.once 'error', (err) ->
            cb err, null

        getMailboxName = (name, boxdata, parent) =>
            mailboxData = {}
            path = name
            if parent
                #attempt to open the mailbox with the parent prefix. 
                imap.openBox parent + '/' + path, (err, box) ->
                    #if it successfully connects use the parent prefix as the path
                    if !err
                        path = parent + '/' + path

            mailboxData['data'] = boxdata
            mailboxData['name'] = name
            mailboxData['path'] = path
            mailboxes[path] =  mailboxData
            if boxdata.children
                _.each boxdata.children, (box, childname) ->
                    getMailboxName childname, box, name


        imap.once 'ready', ->
            imap.getBoxes (err, boxes) ->
                if err
                    return err
                _.each boxes, (box, name) ->
                    getMailboxName name, box, null
                imap.end()

        imap.once 'end', ->
            cb null, mailboxes

    
        
    getMail: (userOptions, cb) ->
        #defaults to opening the 50 latest emails in the inbox
        defaultOptions =
            mailbox: 'INBOX'
            getHeaders: true
            headerFields: ['FROM','TO', 'SUBJECT', 'DATE']
            getBody: true
            firstMail: 1
            lastMail: 50
            returnStructure: true
            markSeen: false
            envelope: false

        options = Object.assign {}, defaultOptions, userOptions

        messages = []

        imap = new iMap @opts
        imap.connect()

        openMailbox: (mailbox, cb) ->
            imap.openBox mailbox, true, cb
            
        imap.once 'error', (err) ->
            cb err, null

        imap.once 'ready', =>
            openMailbox options.mailbox, (err, box) ->
                if err
                    cb err, null
                bodyList = []
                if options.getHeaders
                    bodyList.push 'HEADER.FIELDS (' + options.headerFields.join(' ') + ')'
                if options.getBody
                    bodyList.push 'TEXT'

                f = imap.seq.fetch options.firstMail+':'+options.lastMail, {
                    bodies: bodyList
                    struct: options.returnStructure
                    markSeen: options.markSeen
                    envelope: options.envelope
                }
                f.on 'message', (msg, seqno) ->
                    message = {}
                    msg.on 'body', (stream, info) ->
                        buffer = ''
                        count = 0
                        stream.on 'data', (chunk) ->
                            count += chunk.length
                            buffer += chunk.toString('utf8')

                        stream.once 'end', ->
                            if info.which == 'TEXT'
                                message.body = buffer
                            else
                                message.header = iMap.parseHeader buffer 
                    msg.once 'attributes', (attrs) -> 
                        message.attributes = attrs
                    msg.once 'end', ->
                        messages.push message

                f.once 'end', ->
                    imap.end()

        imap.once 'end', ->
            cb null, messages
