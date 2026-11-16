import ReplyBox from '../ReplyBox.vue';
import fileUploadMixin from 'dashboard/mixins/fileUploadMixin';

const context = () => {
  const state = {
    $t: key => key,
    currentChat: { id: 11 },
    accountId: 1,
    quickReplyIdentity: 'actor-5',
    showFileUpload: true,
    isOnPrivateNote: false,
    isEditorDisabled: false,
    isPrivate: false,
    attachedFiles: [],
    sendWithSignature: false,
    $refs: {
      messageEditor: {
        insertReviewedCannedResponse: vi.fn().mockResolvedValue(true),
      },
    },
    maxSizeFor: () => 40,
  };
  state.quickReplyIsCurrent = values =>
    ReplyBox.methods.quickReplyIsCurrent.call(state, values);
  state.attachFile = values => ReplyBox.methods.attachFile.call(state, values);
  state.onIndirectFileUpload = values =>
    fileUploadMixin.methods.onIndirectFileUpload.call(state, values);
  return state;
};
const intent = file => ({
  content: '**Reviewed** text',
  file,
  accountId: 1,
  conversationId: 11,
  authorityKey: 'actor-5',
});

it('awaits the native local attachment before inserting reviewed Markdown without sending it', async () => {
  const state = context();
  const file = new File(['synthetic'], 'reviewed.pdf', {
    type: 'application/pdf',
  });
  await ReplyBox.methods.insertQuickReply.call(state, intent(file));
  expect(state.attachedFiles).toHaveLength(1);
  expect(state.attachedFiles[0]).toMatchObject({
    currentChatId: 11,
    resource: { file },
    isPrivate: false,
  });
  expect(
    state.$refs.messageEditor.insertReviewedCannedResponse
  ).toHaveBeenCalledWith('**Reviewed** text');
});

it('refuses a late attachment after a conversation changes and preserves the new conversation draft', async () => {
  const state = context();
  const file = new File(['synthetic'], 'reviewed.pdf', {
    type: 'application/pdf',
  });
  const pending = ReplyBox.methods.insertQuickReply.call(state, intent(file));
  state.currentChat = { id: 12 };
  await expect(pending).rejects.toThrow();
  expect(state.attachedFiles).toEqual([]);
  expect(
    state.$refs.messageEditor.insertReviewedCannedResponse
  ).not.toHaveBeenCalled();
});

it('rolls back a pending native attachment when insertion fails without falling back to text', async () => {
  const state = context();
  const unrelated = { resource: { file: new File(['other'], 'other.pdf') } };
  state.attachedFiles.push(unrelated);
  state.$refs.messageEditor.insertReviewedCannedResponse.mockRejectedValue(
    new Error('Editor unavailable')
  );
  const file = new File(['synthetic'], 'reviewed.pdf', {
    type: 'application/pdf',
  });
  await expect(
    ReplyBox.methods.insertQuickReply.call(state, intent(file))
  ).rejects.toThrow('Editor unavailable');
  expect(state.attachedFiles).toEqual([unrelated]);
});

it('preserves the local reviewed file even when the installation uses signed direct uploads', () => {
  const file = new File(['synthetic'], 'reviewed.pdf', {
    type: 'application/pdf',
  });
  const state = {
    ...context(),
    globalConfig: { directUploadsEnabled: true },
    attachedFiles: [{ resource: { file } }],
    getMessageWithQuotedEmailText: value => value,
    setReplyToInPayload: value => value,
    sender: { id: 5 },
  };
  const payload = ReplyBox.methods.getMessagePayload.call(
    state,
    'Reviewed text'
  );
  expect(payload.files).toEqual([file]);
  expect(payload.message).toBe('Reviewed text');
});

it('does not paste a preview clipboard file into the background composer', () => {
  const onFileUpload = vi.fn();
  ReplyBox.methods.onPaste.call(
    {
      isQuickReplyOpen: true,
      showFileUpload: true,
      isOnPrivateNote: false,
      isEditorDisabled: false,
      channelType: 'Channel::Api',
      inbox: {},
      onFileUpload,
    },
    {
      clipboardData: {
        files: [
          new File(['synthetic'], 'clipboard.pdf', { type: 'application/pdf' }),
        ],
      },
    }
  );
  expect(onFileUpload).not.toHaveBeenCalled();
});

it('does not let a send shortcut target the background draft while reviewing', () => {
  expect(
    ReplyBox.methods.isAValidEvent.call(
      {
        isQuickReplyOpen: true,
        isFocused: true,
        isEditorHotKeyEnabled: () => true,
      },
      'cmd_enter'
    )
  ).toBe(false);
});

it('does not turn unresolved expressions from context data into a second native Liquid evaluation', async () => {
  const state = context();
  await expect(
    ReplyBox.methods.insertQuickReply.call(state, {
      ...intent(undefined),
      content: 'Contact: {{ conversation.recent_messages }}',
    })
  ).rejects.toThrow('Quick reply template needs manual review');
  expect(
    state.$refs.messageEditor.insertReviewedCannedResponse
  ).not.toHaveBeenCalled();
});
