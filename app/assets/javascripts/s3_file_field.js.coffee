#= require jquery-fileupload/basic
#= require jquery-fileupload/vendor/tmpl

jQuery.fn.S3FileField = (options) ->

  options = {} unless options?

  # support multiple elements
  if @length > 1
    @each -> $(this).S3Uploader options if @length > 1
    return this

  $this = this

  extractOption = (key) ->
    extracted = options[key]
    delete options[key]
    extracted

  getFormData = (data, form) ->
    formData = undefined
    return data(form) if typeof data is "function"
    return data if $.isArray(data)
    if $.type(data) is "object"
      formData = []
      $.each data, (name, value) ->
        formData.push
          name: name
          value: value
      return formData
    return []

  url = extractOption('url')
  add = extractOption('add')
  done = extractOption('done')
  fail = extractOption('fail')
  extraFormData = extractOption('formData')

  delete options['paramName']
  delete options['singleFileUploads']

  finalFormData = {}

  makeKey = (key, unique_id, file) ->
    filename = to_s3_filename(file.name)
    key.replace('{timestamp}', new Date().getTime()).replace('{unique_id}', unique_id).replace('${filename}', filename)

  settings =
    # File input name must be "file"
    paramName: 'file'

    # S3 doesn't support multiple file uploads
    singleFileUploads: true

    # We don't want to send it to default form url
    url: url || $this.data('url')

    # For IE <= 9 force iframe transport
    forceIframeTransport: do ->
      userAgent = navigator.userAgent.toLowerCase()
      msie = /msie/.test( userAgent ) && !/opera/.test( userAgent )
      msie_version = parseInt((userAgent.match( /.+(?:rv|it|ra|ie)[\/: ]([\d.]+)/ ) || [])[1], 10)
      msie && msie_version <= 9

    add: (e, data) ->
      data.files[0].unique_id = Math.random().toString(36).substr(2,16)
      if add? then add(e, data) else data.submit()

    done: (e, data) ->
      data.result = build_content_object(data.files[0], data.result)
      done(e, data) if done?

    fail: (e, data) ->
      fail(e, data) if fail?

    formData: (form) ->
      unique_id = @files[0].unique_id
      finalFormData[unique_id] =
        key: makeKey($this.data("key"), unique_id, @files[0])
        'Content-Type': @files[0].type
        acl: $this.data('acl')
        'AWSAccessKeyId': $this.data('aws-access-key-id')
        policy: $this.data('policy')
        signature: $this.data('signature')
        success_action_status: "201"
        'X-Requested-With': 'xhr'

      getFormData(finalFormData[unique_id]).concat(getFormData(extraFormData))

  jQuery.extend settings, options

  # to_s3_filename = (filename) ->
  #   trimmed = filename.replace(/^\s+|\s+$/g,'')
  #   strip_before_slash = trimmed.split('\\').slice(-1)[0]
  #   double_encode_quote = strip_before_slash.replace('"', '%22')
  #   encodeURIComponent(double_encode_quote)

  to_s3_filename = (filename) ->
    sanitized = filename.replace(/[^a-zA-Z0-9\.\-]/g, '-')
    sanitized = sanitized.replace(/-+/g, '-').replace(/^-|-$/g, '')
    sanitized.replace("-.", '.')

  build_content_object = (file, result) ->
    content = {}

    if result # Use the S3 response to set the URL to avoid character encodings bugs
      content.url            = $(result).find("Location").text().replace(/%2F/gi, "/").replace('http:', 'https:')
      content.filepath       = $('<a />').attr('href', content.url)[0].pathname
    else # IE <= 9 returns null result so hack is necessary
      domain = settings.url.replace(/\/+$/, '').replace(/^(https?:)?/, 'https:')
      content.filepath   = finalFormData[file.unique_id]['key'].replace('/${filename}', '')
      content.url        = domain + '/' + content.filepath + '/' + to_s3_filename(file.name)

    content.filename   = to_s3_filename(file.name)
    content.filesize   = file.size if 'size' of file
    content.filetype   = file.type if 'type' of file
    content.unique_id  = file.unique_id if 'unique_id' of file
    content

  $this.fileupload settings
