<template>
  <div
    dir="auto"
    class="relative"
  >
    <div
      class="flex justify-between items-end w-full mb-3.5 md:mb-4"
      :class="{ 'mb-2': !field.description }"
    >
      <label
        v-if="showFieldNames"
        class="label text-xl sm:text-2xl py-0 field-name-label"
      >
        <MarkdownContent
          v-if="field.title"
          :string="field.title"
        />
        <template v-else>
          {{ field.name || t('signature') }}
        </template>
      </label>
      <div class="space-x-2 flex flex-none">
        <span
          v-if="isTextSignature && format !== 'typed' && format !== 'upload'"
          class="tooltip"
          :data-tip="t('draw_signature')"
        >
          <a
            id="type_text_button"
            href="#"
            class="btn btn-outline btn-sm font-medium type-text-button"
            @click.prevent="[toggleTextInput(), hideQr()]"
          >
            <IconSignature :width="16" />
            <span class="hidden sm:inline">
              {{ t('draw') }}
            </span>
          </a>
        </span>
        <span
          v-else-if="withTypedSignature && format !== 'typed' && format !== 'drawn' && format !== 'upload'"
          class="tooltip ml-2"
          :class="{ 'hidden sm:inline': modelValue || computedPreviousValue }"
          :data-tip="t('type_text')"
        >
          <a
            id="type_text_button"
            href="#"
            class="btn btn-outline btn-sm font-medium inline-flex flex-nowrap type-text-button"
            @click.prevent="[toggleTextInput(), hideQr()]"
          >
            <IconTextSize :width="16" />
            <span class="hidden sm:inline">
              {{ t('type') }}
            </span>
          </a>
        </span>
        <span
          v-if="format !== 'typed' && format !== 'drawn' && format !== 'upload' && format !== 'drawn_or_typed'"
          class="tooltip"
          :class="{ 'hidden sm:inline': modelValue || computedPreviousValue }"
          :data-tip="t('take_photo')"
        >
          <label class="btn btn-outline btn-sm font-medium inline-flex flex-nowrap upload-image-button">
            <IconCamera :width="16" />
            <input
              :key="uploadImageInputKey"
              type="file"
              hidden
              accept="image/*"
              @change="drawImage"
            >
            <span class="hidden sm:inline">
              {{ t('upload') }}
            </span>
          </label>
        </span>
        <a
          v-if="modelValue || computedPreviousValue"
          href="#"
          class="btn btn-outline btn-sm font-medium reupload-button"
          @click.prevent="remove"
        >
          <IconReload :width="16" />
          {{ t(format === 'upload' ? 'reupload' : 'redraw') }}
        </a>
        <span
          v-if="withQrButton && !modelValue && !computedPreviousValue && format !== 'typed' && format !== 'upload'"
          class=" tooltip"
          :data-tip="t('drawn_signature_on_a_touchscreen_device')"
        >
          <a
            href="#"
            class="btn btn-sm btn-neutral font-medium hidden md:flex"
            :class="{ 'btn-outline': !isShowQr, 'text-white': isShowQr }"
            @click.prevent="isShowQr ? hideQr() : [isTextSignature = false, showQr()]"
          >
            <IconQrcode
              :width="19"
              :height="19"
            />
          </a>
        </span>
        <a
          href="#"
          :title="t('minimize')"
          class="py-1.5 inline md:hidden"
          @click.prevent="$emit('minimize')"
        >
          <IconArrowsDiagonalMinimize2
            :width="20"
            :height="20"
          />
        </a>
      </div>
    </div>
    <div
      v-if="field.description"
      dir="auto"
      class="mb-3 px-1 field-description-text"
    >
      <MarkdownContent :string="field.description" />
    </div>
    <AppearsOn :field="field" />
    <input
      :value="modelValue || computedPreviousValue"
      type="hidden"
      :name="`values[${field.uuid}]`"
    >
    <img
      v-if="modelValue || computedPreviousValue"
      :src="attachmentsIndex[modelValue || computedPreviousValue].url"
      class="mx-auto bg-white border border-base-300 rounded max-h-44"
    >
    <FileDropzone
      v-if="format === 'upload' && !modelValue && !computedPreviousValue"
      :message="`${t('upload')} ${field.name || t('signature')}`"
      :submitter-slug="submitterSlug"
      :dry-run="dryRun"
      :accept="'image/*'"
      @upload="[$emit('attached', $event[0]), $emit('update:model-value', $event[0].uuid)]"
    />
    <div
      v-else
      class="relative"
    >
      <div
        v-if="!modelValue && !computedPreviousValue && !isShowQr && !isTextSignature && isSignatureStarted"
        class="absolute top-0.5 right-0.5"
      >
        <a
          href="#"
          class="btn btn-ghost font-medium btn-xs md:btn-sm"
          @click.prevent="[clear(), hideQr()]"
        >
          <IconReload :width="16" />
          {{ t('clear') }}
        </a>
      </div>
      <div
        v-if="isTextSignature"
        class="absolute top-0 right-0 left-0 bottom-0"
      />
      <canvas
        v-show="!modelValue && !computedPreviousValue"
        ref="canvas"
        style="padding: 1px; 0"
        class="bg-white border border-base-300 rounded-2xl w-full draw-canvas"
      />
      <div
        v-if="isShowQr"
        class="top-0 bottom-0 right-0 left-0 absolute bg-white rounded-2xl m-0.5"
      />
      <div
        v-if="isShowQr"
        class="top-0 bottom-0 right-0 left-0 absolute bg-base-content/10 rounded-2xl"
      >
        <div
          class="absolute top-1.5 right-1.5 tooltip"
        >
          <a
            href="#"
            class="btn btn-sm btn-circle btn-normal btn-outline"
            @click.prevent="hideQr"
          >
            <IconX />
          </a>
        </div>
        <div class="flex items-center justify-center w-full h-full p-4">
          <div
            class="bg-white p-4 rounded-xl h-full"
          >
            <canvas
              ref="qrCanvas"
              class="h-full"
              width="132"
              height="132"
            />
          </div>
        </div>
      </div>
    </div>
    <input
      v-if="isTextSignature && !modelValue && !computedPreviousValue"
      id="signature_text_input"
      ref="textInput"
      class="base-input !text-2xl w-full mt-6"
      :required="field.required && !isSignatureStarted"
      :placeholder="`${t('type_signature_here')}...`"
      type="text"
      @input="updateWrittenSignature"
    >
    <select
      v-if="requireSigningReason && !isOtherReason"
      class="select base-input !text-2xl w-full mt-6 text-center"
      :class="{ 'text-gray-300': !reason }"
      required
      :name="`values[${field.preferences.reason_field_uuid}]`"
      @change="$event.target.value === 'other' ? [reason = '', isOtherReason = true] : $emit('update:reason', $event.target.value)"
    >
      <option
        value=""
        disabled
        :selected="!reason"
        class="text-gray-300"
      >
        {{ t('select_a_reason') }}
      </option>
      <option
        v-for="(label, option) in defaultReasons"
        :key="option"
        :value="option"
        :selected="reason === option"
        class="text-base-content"
      >
        {{ label }}
      </option>
      <option
        value="other"
        class="text-base-content"
      >
        {{ t('other') }}
      </option>
    </select>
    <input
      v-if="requireSigningReason && isOtherReason"
      class="base-input !text-2xl w-full mt-6"
      required
      :name="`values[${field.preferences.reason_field_uuid}]`"
      :placeholder="t('type_here_')"
      :value="reason"
      type="text"
      @input="$emit('update:reason', $event.target.value)"
    >
    <input
      v-if="requireSigningReason"
      hidden
      name="with_reason"
      :value="field.preferences.reason_field_uuid"
    >
    <div
      v-if="isShowQr"
      dir="auto"
      class="text-base-content/60 text-xs text-center w-full mt-1"
    >
      {{ t('scan_the_qr_code_with_the_camera_app_to_open_the_form_on_mobile_and_draw_your_signature') }}
    </div>
    <div
      v-else-if="withDisclosure"
      dir="auto"
      class="text-base-content/60 text-xs text-center w-full mt-1"
    >
      {{ t('by_clicking_you_agree_to_the').replace('{button}', buttonText.charAt(0).toUpperCase() + buttonText.slice(1)) }} <a
        href="https://www.docuseal.com/esign-disclosure"
        target="_blank"
      >
        <span class="inline md:hidden">
          {{ t('esignature_disclosure') }}
        </span>
        <span class="hidden md:inline">
          {{ t('electronic_signature_disclosure') }}
        </span>
      </a>
    </div>
    <div
      v-else
      class="mt-5 md:mt-7"
    />
  </div>
</template>

<script>
import { IconReload, IconCamera, IconSignature, IconTextSize, IconArrowsDiagonalMinimize2, IconQrcode, IconX } from '@tabler/icons-vue'
import { cropCanvasAndExportToPNG } from './crop_canvas'
import { isValidSignatureCanvas } from './validate_signature'
import SignaturePad from 'signature_pad'
import AppearsOn from './appears_on'
import FileDropzone from './dropzone'
import MarkdownContent from './markdown_content'
import { v4 } from 'uuid'

let isFontLoaded = false

const scale = 3

export default {
  name: 'SignatureStep',
  components: {
    AppearsOn,
    IconReload,
    FileDropzone,
    IconCamera,
    IconQrcode,
    MarkdownContent,
    IconX,
    IconTextSize,
    IconSignature,
    IconArrowsDiagonalMinimize2
  },
  inject: ['baseUrl', 't'],
  props: {
    field: {
      type: Object,
      required: true
    },
    requireSigningReason: {
      type: Boolean,
      required: false,
      default: false
    },
    submitter: {
      type: Object,
      required: true
    },
    showFieldNames: {
      type: Boolean,
      required: false,
      default: true
    },
    dryRun: {
      type: Boolean,
      required: false,
      default: false
    },
    withDisclosure: {
      type: Boolean,
      required: false,
      default: false
    },
    withQrButton: {
      type: Boolean,
      required: false,
      default: false
    },
    buttonText: {
      type: String,
      required: false,
      default: 'Submit'
    },
    withTypedSignature: {
      type: Boolean,
      required: false,
      default: true
    },
    rememberSignature: {
      type: Boolean,
      required: false,
      default: false
    },
    attachmentsIndex: {
      type: Object,
      required: false,
      default: () => ({})
    },
    previousValue: {
      type: String,
      required: false,
      default: ''
    },
    reason: {
      type: String,
      required: false,
      default: ''
    },
    modelValue: {
      type: String,
      required: false,
      default: ''
    }
  },
  emits: ['attached', 'update:model-value', 'start', 'minimize', 'update:reason'],
  data () {
    return {
      isSignatureStarted: false,
      isShowQr: false,
      isOtherReason: false,
      isUsePreviousValue: true,
      isTextSignature: this.field.preferences?.format === 'typed',
      uploadImageInputKey: Math.random().toString()
    }
  },
  computed: {
    submitterSlug () {
      return this.submitter.slug
    },
    format () {
      return this.field.preferences?.format
    },
    defaultReasons () {
      return {
        [this.t('approved_by')]: this.t('approved'),
        [this.t('reviewed_by')]: this.t('reviewed'),
        [this.t('authored_by')]: this.t('authored_by_me')
      }
    },
    computedPreviousValue () {
      if (this.isUsePreviousValue && this.field.required === true) {
        return this.previousValue
      } else {
        return null
      }
    }
  },
  created () {
    this.isSignatureStarted = !!this.computedPreviousValue

    if (this.requireSigningReason) {
      this.field.preferences ||= {}
      this.field.preferences.reason_field_uuid ||= v4()
      this.isOtherReason = this.reason && !this.defaultReasons[this.reason]
    }
  },
  async mounted () {
    this.$nextTick(() => {
      if (this.$refs.canvas) {
        this.$refs.canvas.width = this.$refs.canvas.parentNode.clientWidth * scale
        this.$refs.canvas.height = this.$refs.canvas.parentNode.clientWidth * scale / 3

        this.$refs.canvas.getContext('2d').scale(scale, scale)
      }
    })

    if (this.$refs.canvas) {
      this.pad = new SignaturePad(this.$refs.canvas)

      if (this.field.preferences?.color) {
        this.pad.penColor = this.field.preferences.color
      }

      this.pad.addEventListener('endStroke', () => {
        this.isSignatureStarted = true

        this.$emit('start')
      })

      this.intersectionObserver = new IntersectionObserver((entries, observer) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            this.$refs.canvas.width = this.$refs.canvas.parentNode.clientWidth * scale
            this.$refs.canvas.height = this.$refs.canvas.parentNode.clientWidth * scale / 3

            this.$refs.canvas.getContext('2d').scale(scale, scale)

            this.intersectionObserver?.disconnect()
          }
        })
      })

      this.intersectionObserver.observe(this.$refs.canvas)
    }
  },
  beforeUnmount () {
    this.intersectionObserver?.disconnect()
    this.stopCheckSignature()
  },
  methods: {
    remove () {
      this.$emit('update:model-value', '')

      this.isUsePreviousValue = false
      this.isSignatureStarted = false
    },
    loadFont () {
      if (!isFontLoaded) {
        const font = new FontFace('Dancing Script', `url(${this.baseUrl}/fonts/DancingScript-Regular.otf) format("opentype")`)

        font.load().then((loadedFont) => {
          document.fonts.add(loadedFont)

          isFontLoaded = true
        }).catch((error) => {
          console.error('Font loading failed:', error)
        })
      }
    },
    showQr () {
      this.isShowQr = true

      this.$nextTick(() => {
        import('qr-creator').then(({ default: Qr }) => {
          if (this.$refs.qrCanvas) {
            Qr.render({
              text: `${document.location.origin}/p/${this.submitterSlug}?f=${this.field.uuid.split('-')[0]}`,
              radius: 0.0,
              ecLevel: 'H',
              background: null,
              size: 132
            }, this.$refs.qrCanvas)
          }
        })
      })

      this.startCheckSignature()
    },
    hideQr () {
      this.isShowQr = false

      this.stopCheckSignature()
    },
    startCheckSignature () {
      const after = JSON.stringify(new Date())

      this.checkSignatureInterval = setInterval(() => {
        this.checkSignature({ after })
      }, 2000)
    },
    stopCheckSignature () {
      if (this.checkSignatureInterval) {
        clearInterval(this.checkSignatureInterval)
      }
    },
    checkSignature (params = {}) {
      return fetch(this.baseUrl + '/s/' + this.submitterSlug + '/values?field_uuid=' + this.field.uuid + '&after=' + params.after, {
        method: 'GET'
      }).then(async (resp) => {
        const { attachment } = await resp.json()

        if (attachment?.uuid) {
          this.$emit('attached', attachment)
          this.$emit('update:model-value', attachment.uuid)
          this.hideQr()
        }
      })
    },
    clear () {
      this.pad.clear()

      this.isSignatureStarted = false

      if (this.$refs.textInput) {
        this.$refs.textInput.value = ''
        this.$refs.textInput.focus()
      }
    },
    updateWrittenSignature (e) {
      this.isSignatureStarted = !!e.target.value

      const canvas = this.$refs.canvas
      const context = canvas.getContext('2d')

      const fontFamily = 'Dancing Script'
      const initialFontSize = 44
      const fontStyle = 'italic'
      const fontWeight = ''

      const setFontSize = (size) => {
        context.font = `${fontStyle} ${fontWeight} ${size}px ${fontFamily}`
      }

      const adjustFontSizeToFit = (text, maxWidth, initialSize) => {
        let size = initialSize

        setFontSize(size)

        while (context.measureText(text).width > maxWidth && size > 1) {
          size -= 1
          setFontSize(size)
        }
      }

      adjustFontSizeToFit(e.target.value, canvas.width / scale, initialFontSize)

      context.textAlign = 'center'
      context.clearRect(0, 0, canvas.width / scale, canvas.height / scale)
      context.fillText(e.target.value, canvas.width / 2 / scale, canvas.height / 2 / scale + 11)
    },
    toggleTextInput () {
      this.remove()
      this.clear()
      this.isTextSignature = !this.isTextSignature

      if (this.isTextSignature) {
        this.$nextTick(() => {
          this.$refs.textInput.focus()

          this.loadFont()

          this.$emit('start')
        })
      }
    },
    drawImage (event) {
      this.remove()
      this.clear()
      this.isSignatureStarted = true

      this.drawOnCanvas(event.target.files[0], this.$refs.canvas)

      this.uploadImageInputKey = Math.random().toString()
    },
    drawOnCanvas (file, canvas) {
      if (file && file.type.match('image.*')) {
        const reader = new FileReader()

        reader.onload = (event) => {
          const img = new Image()

          img.src = event.target.result

          img.onload = () => {
            const context = canvas.getContext('2d')

            const aspectRatio = img.width / img.height
            const canvasWidth = canvas.width / scale
            const canvasHeight = canvas.height / scale

            let targetWidth = canvasWidth
            let targetHeight = canvasHeight

            if (canvasWidth / canvasHeight > aspectRatio) {
              targetWidth = canvasHeight * aspectRatio
            } else {
              targetHeight = canvasWidth / aspectRatio
            }

            if (targetHeight > targetWidth) {
              const scale = targetHeight / targetWidth
              targetWidth = targetWidth * scale
              targetHeight = targetHeight * scale
            }

            const x = (canvasWidth - targetWidth) / 2
            const y = (canvasHeight - targetHeight) / 2

            setTimeout(() => {
              context.clearRect(0, 0, canvasWidth, canvasHeight)
              context.drawImage(img, x, y, targetWidth, targetHeight)

              this.$emit('start')
            }, 50)
          }
        }

        reader.readAsDataURL(file)
      }
    },
    maybeSetSignedUuid (signedUuid) {
      try {
        if (window.localStorage && signedUuid && this.rememberSignature) {
          const values = window.localStorage.getItem('signed_signature_uuids')

          let data

          if (values) {
            data = JSON.parse(values)
          } else {
            data = {}
          }

          data[this.submitter.email] = signedUuid

          window.localStorage.setItem('signed_signature_uuids', JSON.stringify(data))
        }
      } catch (e) {
        console.error(e)
      }
    },
    async submit () {
      if (this.modelValue || this.computedPreviousValue) {
        if (this.computedPreviousValue) {
          this.$emit('update:model-value', this.computedPreviousValue)
        }

        return Promise.resolve({})
      }

      if (this.isSignatureStarted && this.pad.toData().length > 0 && !isValidSignatureCanvas(this.pad.toData())) {
        if (this.field.required === true || this.pad.toData().length > 0) {
          alert(this.t('signature_is_too_small_or_simple_please_redraw'))

          return Promise.reject(new Error('Image too small or simple'))
        } else {
          Promise.resolve({})
        }
      }

      return new Promise((resolve, reject) => {
        cropCanvasAndExportToPNG(this.$refs.canvas, { errorOnTooSmall: true }).then(async (blob) => {
          const file = new File([blob], 'signature.png', { type: 'image/png' })

          if (this.dryRun) {
            const reader = new FileReader()

            reader.readAsDataURL(file)

            reader.onloadend = () => {
              const attachment = { url: reader.result, uuid: Math.random().toString() }

              this.$emit('attached', attachment)
              this.$emit('update:model-value', attachment.uuid)

              resolve(attachment)
            }
          } else {
            const formData = new FormData()

            formData.append('file', file)
            formData.append('submitter_slug', this.submitterSlug)
            formData.append('name', 'attachments')
            formData.append('remember_signature', this.rememberSignature)
            formData.append('type', 'signature')

            return fetch(this.baseUrl + '/api/attachments', {
              method: 'POST',
              body: formData
            }).then(async (resp) => {
              if (resp.status === 422 || resp.status === 500) {
                const data = await resp.json()

                return Promise.reject(new Error(data.error))
              }

              const attachment = await resp.json()

              this.$emit('attached', attachment)
              this.$emit('update:model-value', attachment.uuid)

              this.maybeSetSignedUuid(attachment.signed_uuid)

              return resolve(attachment)
            })
          }
        }).catch((error) => {
          if (this.field.required === true) {
            alert(this.t('signature_is_too_small_or_simple_please_redraw'))

            return reject(error)
          } else {
            return resolve({})
          }
        })
      })
    }
  }
}
</script>
