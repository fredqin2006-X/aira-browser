export interface BrowserConfirmationRequest {
  title: ResourceStr;
  message: ResourceStr;
  cancelLabel: ResourceStr;
  confirmLabel: ResourceStr;
  confirmTone?: 'warning' | 'alert';
  onCancel?: () => void;
  onConfirm: () => void;
}

export interface BrowserConfirmationSink {
  confirm(request: BrowserConfirmationRequest): void;
}
